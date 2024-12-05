// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/VARQ.sol";
import "../src/MockUSDC.sol";
import "../src/vTokens.sol";

contract VARQTest is Test {
    VARQ varq;
    MockUSDC usdc;
    vTokens vusd;

    function setUp() public {
        usdc = new MockUSDC();
        varq = new VARQ(address(this), address(usdc));
        vusd = vTokens(varq.tokenProxies(1));
    }

    function testInitialBalance() public {
        uint256 initialBalance = usdc.balanceOf(address(this));
        assertEq(initialBalance, 1e27);  // 1 billion USDC, considering decimals
    }

    function testDepositUSD() public {
        uint256 depositAmount = 1e6 * 1e18;  // 1 million USDC
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);
        assertEq(varq.balanceOf(address(this), 1), depositAmount);
    }

    function testDepositUSDProxy() public {
        uint256 depositAmount = 1e6 * 1e18;  // 1 million USDC
        usdc.approve(address(varq), depositAmount);
        varq.depositUSD(depositAmount);
        //assertEq(varq.balanceOf(address(this), 1), depositAmount);
        assertEq(vusd.balanceOf(address(this)), depositAmount);
    }


    function testvCurrenctExiststate() public {
        string memory symbol = "KES";
        string memory name = "rqtKES";
        varq.addvCurrencyState(1, symbol, name, address(this));

        // Retrieve the entire struct first
        (
            uint256 tokenIdCurrency,
            uint256 tokenIdReserve,
            uint256 oracleRate,
            uint256 S_u,
            uint256 S_f,
            uint256 S_r,
            address oracleUpdater
        ) = varq.vCurrencyStates(1);
        
        address proxyAddress = varq.tokenProxies(tokenIdCurrency);
        vTokens vkes = vTokens(proxyAddress);

        // Try to call a function that exists in vTokens
        try vkes.name() returns (string memory tokenName) {
            assertTrue(true, "proxyAddress points to a vTokens contract");
        } catch {
            fail();
        }

        string memory tokenName = vkes.name();
        assertEq(tokenName, "KES", "Token name should be KES");

        string memory tokenSymbol = vkes.symbol();
        assertEq(tokenSymbol, "vKES", "Token name should be vKES");

        address proxyAddress2 = varq.tokenProxies(tokenIdReserve);
        vTokens vrqt = vTokens(proxyAddress2);

        string memory tokenName2 = vrqt.name();
        assertEq(tokenName2, "rqtKES", "Token name should be rqtKES");

        string memory tokenSymbol2 = vrqt.symbol();
        assertEq(tokenSymbol2, "vRQT_KES", "Token name should be vKES");
    }

}
