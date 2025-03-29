from decimal import Decimal, getcontext

# Set precision to 28 decimal places (adjustable as needed)
getcontext().prec = 28

class VFE:
    def __init__(self, u_delta, init_oracle_rate, init_ratio, fee):
        # Initialize all variables with Decimal type
        self.usdcFees = Decimal('0.0')        # Accumulated fees in USDC
        self.feeRate = Decimal('0.0')         # Fee rate applied to USDC deployments
        self.usdcSupply = Decimal('0.0')      # Supply of USDC deployed
        self.redemptionSupply = Decimal('0.0') # Supply of redemption tokens issued
        self.fiatSupply = Decimal('0.0')      # Supply of fiat tokens issued
        self.redemptionReserves = Decimal('0.0') # Redemption tokens in the AMM pool X reserves
        self.fiatReserves = Decimal('0.0')    # Fiat tokens in the AMM pool Y reserves
        self.fiatExtra = Decimal('0.0')       # Extra fiat tokens minted from the LP
        self.oracleRate = Decimal(str(init_oracle_rate))  # The Oracle rate from a central bank
        self.fiatExternal = Decimal('0.0')    # Fiat tokens minted as transferable ERC20 tokens floating external to the protocol

        # Set the initial fee rate
        self._updateFee(fee)

        # Convert inputs to Decimal
        u_delta = Decimal(str(u_delta))
        init_ratio = Decimal(str(init_ratio))

        # Initialize with varqForward (no fee applied directly here)
        r_delta, f_delta = self.varqForward(u_delta)

        # Set initial values
        y_to_set = r_delta * init_ratio
        self.redemptionReserves = r_delta
        self.fiatReserves = y_to_set
        self.fiatExtra = f_delta - y_to_set

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
    def varqForward(self, u_delta_postfee):
        r_delta = u_delta_postfee * self._getLambda()
        f_delta = u_delta_postfee * self.oracleRate
        self.usdcSupply += u_delta_postfee
        self.redemptionSupply += r_delta
        self.fiatSupply += f_delta
        return r_delta, f_delta

    # Method for forward swap in the AMM pool
    def swapForward(self, r_delta):
        r_delta = Decimal(str(r_delta))
        delta_out = self._swapGivenInCalcOut(r_delta, self.redemptionReserves, self.fiatReserves)
        self.redemptionReserves += r_delta
        self.fiatReserves -= delta_out
        return delta_out

    # Combined forward method for USDC deployment and swap
    def forwardVarqSwap(self, u_delta):
        u_delta_postfee = self.applyFee(u_delta)
        r_delta, f_delta = self.varqForward(u_delta_postfee)
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
        delta_in, new_in, new_out = self._swapGivenOutCalcIn(r_delta, self.redemptionReserves, self.fiatReserves)
        self.redemptionReserves = new_in
        self.fiatReserves = new_out
        return delta_in

    # Method to reverse issuance with a reserve check
    def varqReverse(self, r_swap, f_remainder):
        r_swap = Decimal(str(r_swap))
        f_remainder = Decimal(str(f_remainder))
        p_r = self._getP_R()
        if f_remainder < r_swap * p_r:
            raise ValueError(f"Insufficient F to burn: f_remainder ({f_remainder}) < r_swap * P_R ({r_swap * p_r})")
        self.usdcSupply -= r_swap
        self.redemptionSupply -= r_swap
        self.fiatSupply -= f_remainder 
        u_prefee = r_swap
        return u_prefee

    # Combined reverse method for swap and issuance reversal
    def reverseVarqSwap(self, f_to_burn, r_expected=None):
        f_to_burn = Decimal(str(f_to_burn))
        if r_expected is None:
            r_expected = f_to_burn
        else:
            r_expected = Decimal(str(r_expected))
        f_swap = self.swapReverse(r_expected)
        f_delta = f_to_burn - f_swap
        u_prefee = self.varqReverse(r_expected, f_delta)
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

# Helper function to calculate optimal redemption amount
def calcOptimalR(f_e, vfe):
    f_e = Decimal(str(f_e))
    y_f = vfe.fiatReserves
    x_r = vfe.redemptionReserves
    p_r = vfe._getP_R()
    a = p_r
    b = -(f_e + y_f + p_r * x_r)
    c = f_e * x_r
    discriminant = b**2 - Decimal('4') * a * c
    sqrt_disc = getcontext().sqrt(discriminant)
    return (-b - sqrt_disc) / (Decimal('2') * a)

# Example Usage
if __name__ == "__main__":
    obj = VFE(1000000, 120, 20, 0.00)
    
    print(f"Initial values:")
    print(f"feeRate: {obj.feeRate}")
    print(f"usdcFees: {obj.usdcFees}")
    print(f"usdcSupply: {obj.usdcSupply}")
    print(f"redemptionSupply: {obj.redemptionSupply}")
    print(f"fiatSupply: {obj.fiatSupply}")
    print(f"redemptionReserves: {obj.redemptionReserves}")
    print(f"fiatReserves: {obj.fiatReserves}")
    print(f"fiatExtra: {obj.fiatExtra}")
    print(f"oracleRate: {obj.oracleRate}")
    print(f"fiatExternal: {obj.fiatExternal}")
    print(f"Lambda: {obj._getLambda()}")
    
    f_out = obj.forwardVarqSwap(10)
    print(f"\nAfter forwardVarqSwap(10):")
    print(f"f_out: {f_out}")
    print(f"usdcFees: {obj.usdcFees}")
    print(f"usdcSupply: {obj.usdcSupply}")
    print(f"redemptionSupply: {obj.redemptionSupply}")
    print(f"fiatSupply: {obj.fiatSupply}")
    print(f"redemptionReserves: {obj.redemptionReserves}")
    print(f"fiatReserves: {obj.fiatReserves}")
    print(f"fiatExtra: {obj.fiatExtra}")
    print(f"fiatExternal: {obj.fiatExternal}")
    
    f_to_burn = 100
    r_optimal = calcOptimalR(f_to_burn, obj)
    print(f"\nOptimal R for f_to_burn={f_to_burn}: {r_optimal}")
    
    try:
        f_out_reverse = obj.reverseVarqSwap(f_to_burn, r_optimal)
        print(f"\nAfter reverseVarqSwap({f_to_burn}, {r_optimal}):")
        print(f"usd_out: {f_out_reverse}")
        print(f"usdcFees: {obj.usdcFees}")
        print(f"usdcSupply: {obj.usdcSupply}")
        print(f"redemptionSupply: {obj.redemptionSupply}")
        print(f"fiatSupply: {obj.fiatSupply}")
        print(f"redemptionReserves: {obj.redemptionReserves}")
        print(f"fiatReserves: {obj.fiatReserves}")
        print(f"fiatExtra: {obj.fiatExtra}")
        print(f"fiatExternal: {obj.fiatExternal}")
    except ValueError as e:
        print(f"\nError in reverseVarqSwap({f_to_burn}, {r_optimal}): {e}")
