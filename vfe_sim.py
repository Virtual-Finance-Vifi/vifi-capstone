from decimal import Decimal, getcontext
import pandas as pd
import matplotlib.pyplot as plt
from itertools import product

# Set precision to 28 decimal places (adjustable as needed)
getcontext().prec = 28

#virtual fiat environment
class VFE:
    def __init__(self, u_delta, u_delta_for_fiat, init_oracle_rate, init_ratio, fee):
        # Initialize all variables with Decimal type
        self.usdcFees = Decimal('0.0')        # Accumulated fees in USDC
        self.feeRate = Decimal('0.0')         # Fee rate applied to USDC deployments
        self.usdcSupply = Decimal('0.0')      # Supply of USDC deployed
        self.redemptionSupply = Decimal('0.0') # Supply of redemption tokens issued
        self.fiatSupply = Decimal('0.0')      # Supply of fiat tokens issued
        self.redemptionPool = Decimal('0.0') # Redemption tokens in the AMM pool X reserves
        self.fiatPool = Decimal('0.0')    # Fiat tokens in the AMM pool Y reserves
        self.fiatExtra = Decimal('0.0')       # Extra fiat tokens minted from the LP
        self.oracleRate = Decimal(str(init_oracle_rate))  # The Oracle rate from a central bank
        self.fiatExternal = Decimal('0.0')    # Fiat tokens minted as transferable ERC20 tokens floating external to the protocol

        # Set the initial fee rate
        self._updateFee(fee)

        # Convert inputs to Decimal
        u_delta = Decimal(str(u_delta))
        init_ratio = Decimal(str(init_ratio))

        # Initialize with varqExpansion (no fee applied directly here)
        r_delta, f_delta = self.varqExpansion(u_delta)

        #calc external fiat
        external_fiat = u_delta_for_fiat*(init_oracle_rate+init_ratio)
        # Set initial values
        y_to_set = r_delta * init_ratio
        self.redemptionPool = r_delta
        self.fiatPool = y_to_set
        self.fiatExtra = f_delta - y_to_set - external_fiat
        self.fiatExternal = external_fiat

    # Private method to update fee rate
    def _updateFee(self, fee):
        self.feeRate = Decimal(str(fee))

    # Method to handle fee application on USDC deployments
    def applyFee(self, u_delta):
        u_delta = Decimal(str(u_delta))
        u_delta_fee = u_delta * self.feeRate
        self.usdcFees += u_delta_fee
        return u_delta - u_delta_fee

    # Method to calculate forward values for token issuance
    def varqExpansion(self, u_delta_postfee):
        r_delta = u_delta_postfee * self._getLambda()
        f_delta = u_delta_postfee * self.oracleRate
        self.usdcSupply += u_delta_postfee
        self.redemptionSupply += r_delta
        self.fiatSupply += f_delta
        return r_delta, f_delta

    # Method for forward swap in the AMM pool
    def swapForward(self, r_delta):
        r_delta = Decimal(str(r_delta))
        delta_out = self._swapGivenInCalcOut(r_delta, self.redemptionPool, self.fiatPool)
        self.redemptionPool += r_delta
        self.fiatPool -= delta_out
        return delta_out

    # Combined forward method for USDC deployment and swap
    def ExpansionSwap(self, u_delta):
        u_delta_postfee = self.applyFee(u_delta)
        r_delta, f_delta = self.varqExpansion(u_delta_postfee)
        f_swap = self.swapForward(r_delta)
        f_out = f_delta + f_swap
        self.fiatExternal += f_out
        return f_out

    # Swap utility: calculate fiat out given redemption in
    def _swapGivenInCalcOut(self, delta_in, current_in, current_out):
        delta_in = Decimal(str(delta_in))
        current_in = Decimal(str(current_in))
        current_out = Decimal(str(current_out))
        delta_out = current_out - ((current_in * current_out) / (current_in + delta_in))
        return delta_out

    # Swap utility: calculate redemption in given fiat out
    def _swapGivenOutCalcIn(self, delta_out, current_in, current_out):
        delta_out = Decimal(str(delta_out))
        current_in = Decimal(str(current_in))
        current_out = Decimal(str(current_out))
        delta_in = current_in - ((current_in * current_out) / (current_out + delta_out))
        new_in = current_in - delta_in
        new_out = current_out + delta_out
        return delta_in, new_in, new_out

    # Method for reverse swap in the AMM pool
    def swapReverse(self, r_delta):
        r_delta = Decimal(str(r_delta))
        delta_in, new_in, new_out = self._swapGivenOutCalcIn(r_delta, self.redemptionPool, self.fiatPool)
        self.redemptionPool = new_in
        self.fiatPool = new_out
        return delta_in

    # Method to reverse issuance with a reserve check
    def varqContraction(self, r_swap, f_remainder):
        r_swap = Decimal(str(r_swap))
        f_remainder = Decimal(str(f_remainder))
        p_r = self._getP_R()
        if f_remainder < r_swap * p_r:
            raise ValueError(f"Insufficient F to burn: f_remainder ({f_remainder}) < r_swap * P_R ({r_swap * p_r})")
        self.usdcSupply -= r_swap
        self.redemptionSupply -= r_swap
        self.fiatSupply -= r_swap * p_r 
        self.fiatExternal -= r_swap * p_r
        f_unutilized = f_remainder - r_swap * p_r
        u_prefee = r_swap
        return u_prefee, f_unutilized

    # Combined reverse method for swap and issuance reversal
    def ContractionSwap(self, f_to_burn, r_expected=None):
        f_to_burn = Decimal(str(f_to_burn))
        
        # Check if f_to_burn exceeds fiatExternal
        if f_to_burn > self.fiatExternal:
            if print_bit:
                print(f"Warning: f_to_burn ({f_to_burn}) exceeds fiatExternal ({self.fiatExternal})")
            f_to_burn = self.fiatExternal
        
        if r_expected is None:
            r_expected = f_to_burn
        else:
            r_expected = Decimal(str(r_expected))
            
        f_swap = self.swapReverse(r_expected)
        f_delta = f_to_burn - f_swap
        u_prefee, f_unutilized = self.varqContraction(r_expected, f_delta)
        u_delta_postfee = self.applyFee(u_prefee)
        return u_delta_postfee

    # Private method to get the price ratio (fiat/redemption)
    def _getP_R(self):
        return self.fiatSupply / self.redemptionSupply

    # Private method to get the flux ratio
    def _getFluxRatio(self):
        return self._getP_R() / self.oracleRate

    # Private method to get the reserve ratio
    def _getReserveRatio(self):
        return self.fiatSupply / self.usdcSupply

    # Private method to get lambda adjustment factor
    def _getLambda(self):
        if self.usdcSupply == Decimal('0'):
            return Decimal('1')
        flux_ratio = self._getFluxRatio()
        reserve_ratio = self._getReserveRatio()
        if flux_ratio > Decimal('1') and reserve_ratio == Decimal('1'):
            return Decimal('1')
        return flux_ratio

    def print_status(self, message="Current Status:", 
                    print_basic=True,
                    print_valuations=True,
                    print_enabled=True):
        """
        Print status of VFE with configurable outputs
        Args:
            message (str): Header message for the status print
            print_basic (bool): Print basic state variables
            print_valuations (bool): Print USD valuations
            print_enabled (bool): Master switch to enable/disable all printing
        """
        if not print_enabled:
            return
            
        if print_basic or print_valuations:
            print(f"\n{message}")
            
        if print_basic:
            print("Basic State:")
            print(f"  feeRate: {self.feeRate}")
            print(f"  usdcFees: {self.usdcFees}")
            print(f"  usdcSupply: {self.usdcSupply}")
            print(f"  redemptionSupply: {self.redemptionSupply}")
            print(f"  fiatSupply: {self.fiatSupply}")
            print(f"  redemptionPool: {self.redemptionPool}")
            print(f"  fiatPool: {self.fiatPool}")
            print(f"  fiatExtra: {self.fiatExtra}")
            print(f"  oracleRate: {self.oracleRate}")
            print(f"  fiatExternal: {self.fiatExternal}")
            print(f"  Lambda: {self._getLambda()}")
        
        if print_valuations:
            denominator = (self.fiatSupply/self.redemptionSupply) + (self.fiatPool/self.redemptionPool)
            valuations = {
                'fiatPool': self.fiatPool / denominator,
                'fiatExtra': self.fiatExtra / denominator,
                'redemptionPool': self.redemptionPool * (self.fiatPool/self.redemptionPool) / denominator,
                'fiatExternal': self.fiatExternal / denominator
            }
            
            print("\nValuations (in USD):")
            print(f"  fiatPool: {valuations['fiatPool']}")
            print(f"  fiatExtra: {valuations['fiatExtra']}")
            print(f"  redemptionPool: {valuations['redemptionPool']}")
            print(f"  Total LP Claims: {sum(v for k, v in valuations.items() if k != 'fiatExternal')}")
            print(f"  fiatExternal: {valuations['fiatExternal']}")

# Helper function to calculate optimal redemption amount
def calcOptimalR(f_e, vfe):
    f_e = Decimal(str(f_e))
    y_f = vfe.fiatPool
    x_r = vfe.redemptionPool
    p_r = vfe._getP_R()
    a = p_r
    b = -(f_e + y_f + p_r * x_r)
    c = f_e * x_r
    discriminant = b**2 - Decimal('4') * a * c
    sqrt_disc = getcontext().sqrt(discriminant)
    return (-b - sqrt_disc) / (Decimal('2') * a)

##### instantiates the VFE object and runs the 2 opposing trades, one is a forward trade and the other is a reverse trade
def run_trading_sequence(num_iterations=1, trade_size_usd=10, fee=0.00, vol_shift=0.0, print_bit=False, print_basic=True, print_valuations=True):
    # Only apply these if master switch is on
    print_basic = print_basic and print_bit
    print_valuations = print_valuations and print_bit
    
    # Convert inputs to Decimal
    trade_size_usd = Decimal(str(trade_size_usd))
    vol_shift = Decimal(str(vol_shift))
    
    obj = VFE(u_delta=1000, u_delta_for_fiat=100, init_oracle_rate=4, init_ratio=1, fee=fee)
    
    # Calculate initial LP valuation
    denominator = (obj.fiatSupply/obj.redemptionSupply) + (obj.fiatPool/obj.redemptionPool)
    initial_valuations = {
        'fiatPool': obj.fiatPool / denominator,
        'fiatExtra': obj.fiatExtra / denominator,
        'redemptionPool': obj.redemptionPool * (obj.fiatPool/obj.redemptionPool) / denominator
    }
    initial_lp_value = sum(initial_valuations.values())
    
    # Initial state
    obj.print_status("Initial values:", 
                     print_basic=print_basic,
                     print_valuations=print_valuations,
                     print_enabled=print_bit)

    for i in range(num_iterations):
        if print_bit:
            print(f"\n--- Iteration {i+1}/{num_iterations} ---")
        
        # Expansion phase
        f_out = obj.ExpansionSwap(trade_size_usd)
        if print_bit:
            print(f"\nExpansionSwap({trade_size_usd}) output: {f_out}")
        obj.print_status(f"After ExpansionSwap({trade_size_usd}):", 
                         print_basic=print_basic,
                         print_valuations=print_valuations,
                         print_enabled=print_bit)

        # Contraction phase
        contration_vol_fiat = ((obj.fiatSupply/obj.redemptionSupply) + 
                              (obj.fiatPool/obj.redemptionPool)) * (trade_size_usd * (Decimal('1')+vol_shift))
        if print_bit:
            print(f"\nAmount of usd volume to contract={trade_size_usd * (1+vol_shift)}: {contration_vol_fiat}")

        r_optimal = calcOptimalR(contration_vol_fiat, obj)
        if print_bit:
            print(f"\nOptimal R for contration_vol_fiat={contration_vol_fiat}: {r_optimal}")
        
        try:
            f_out_reverse = obj.ContractionSwap(contration_vol_fiat, r_optimal-Decimal('0.05'))
            if print_bit:
                print(f"\nContractionSwap output: {f_out_reverse}")
            obj.print_status(f"After ContractionSwap({contration_vol_fiat}, {r_optimal}):",
                             print_basic=print_basic,
                             print_valuations=print_valuations,
                             print_enabled=print_bit)
        except ValueError as e:
            if print_bit:
                print(f"\nError in ContractionSwap({contration_vol_fiat}, {r_optimal}): {e}")
            obj.print_status("Status after error:",
                             print_basic=print_basic,
                             print_valuations=print_valuations,
                             print_enabled=print_bit)
            break

    # Calculate final LP valuation
    denominator = (obj.fiatSupply/obj.redemptionSupply) + (obj.fiatPool/obj.redemptionPool)
    final_valuations = {
        'fiatPool': obj.fiatPool / denominator,
        'fiatExtra': obj.fiatExtra / denominator,
        'redemptionPool': obj.redemptionPool * (obj.fiatPool/obj.redemptionPool) / denominator
    }
    final_lp_value = sum(final_valuations.values())

    return obj, initial_lp_value, final_lp_value

def run_analysis():
    # Define parameter ranges
    iterations_range = [10, 100, 1000]
    vol_shift_range = [-0.2, -0.1, 0, 0.1, 0.2]
    fee_range = [0.003, 0.01, 0.03]
    
    # Create empty DataFrame to store results
    results = []
    
    # Run simulations for all combinations
    for iterations, vol_shift, fee in product(iterations_range, vol_shift_range, fee_range):
        _, initial_lp, final_lp = run_trading_sequence(
            num_iterations=iterations,
            trade_size_usd=10,
            fee=fee,
            vol_shift=vol_shift,
            print_bit=False
        )
        
        lp_pnl = final_lp - initial_lp
        lp_pnl_percentage = (final_lp / initial_lp - 1) * 100  # Convert to percentage
        
        results.append({
            'iterations': iterations,
            'vol_shift': vol_shift,
            'fee': fee,
            'lp_pnl': float(lp_pnl),  # Convert Decimal to float for plotting
            'lp_pnl_percentage': float(lp_pnl_percentage)  # Convert Decimal to float for plotting
        })
    
    # Convert results to DataFrame
    df = pd.DataFrame(results)
    
    # Create pivot tables for both metrics
    pivot_table_abs = df.pivot_table(
        values='lp_pnl',
        index=['iterations', 'fee'],
        columns='vol_shift',
        aggfunc='first'
    )
    
    pivot_table_pct = df.pivot_table(
        values='lp_pnl_percentage',
        index=['iterations', 'fee'],
        columns='vol_shift',
        aggfunc='first'
    )
    
    # Print tables
    print("\nLP PnL Results (Absolute):")
    print(pivot_table_abs)
    print("\nLP PnL Results (Percentage):")
    print(pivot_table_pct)
    
    # Create plots (2 rows: absolute and percentage)
    plt.figure(figsize=(15, 10))
    
    # First row: Absolute PnL
    for i, iterations in enumerate(iterations_range, 1):
        plt.subplot(2, 3, i)
        for fee in fee_range:
            data = df[(df['iterations'] == iterations) & (df['fee'] == fee)]
            plt.plot(data['vol_shift'], data['lp_pnl'], 
                    marker='o', 
                    label=f'fee={fee}')
        
        plt.title(f'Absolute PnL\nIterations: {iterations}')
        plt.xlabel('Volume Shift')
        plt.ylabel('LP PnL (Absolute)')
        plt.grid(True)
        plt.legend()
    
    # Second row: Percentage PnL
    for i, iterations in enumerate(iterations_range, 1):
        plt.subplot(2, 3, i+3)
        for fee in fee_range:
            data = df[(df['iterations'] == iterations) & (df['fee'] == fee)]
            plt.plot(data['vol_shift'], data['lp_pnl_percentage'], 
                    marker='o', 
                    label=f'fee={fee}')
        
        plt.title(f'Percentage PnL\nIterations: {iterations}')
        plt.xlabel('Volume Shift')
        plt.ylabel('LP PnL (%)')
        plt.grid(True)
        plt.legend()
    
    plt.tight_layout()
    
    # Create filename with parameters
    filename = f"lp_pnl_iter_{min(iterations_range)}-{max(iterations_range)}_volshift_{min(vol_shift_range)}-{max(vol_shift_range)}_fee_{min(fee_range)}-{max(fee_range)}.png"
    plt.savefig(filename, dpi=300, bbox_inches='tight')
    print(f"\nPlot saved as: {filename}")
    
    #plt.show()
    
    return df, pivot_table_abs, pivot_table_pct

if __name__ == "__main__":
    df, pivot_abs, pivot_pct = run_analysis()



