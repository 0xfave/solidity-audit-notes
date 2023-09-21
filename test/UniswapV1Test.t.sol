// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../src/UniswapV1/Exchange.sol";
import "../src/UniswapV1/Token.sol";
import "forge-std/console.sol";

contract UniswapV1Test is Test {
    Exchange exchange;
    Token token;

    uint128 constant INITIAL_MINT = 100_000_000 ether;
    uint128 constant INITIAL_LIQUIDITY = 100 ether;
    uint128 constant USER_LIQUIDITY = 1000 ether;
    uint128 constant TOKEN_AMOUNT = 2000 ether;

    address deployer = makeAddr("deployer");
    address user = makeAddr("user");
    address user2 = makeAddr("user2");

    function setUp() public {
        vm.deal(deployer, 10000 ether);
        vm.deal(user, 10000 ether);
        vm.deal(user2, 10000 ether);

        vm.startPrank(deployer);
        token = new Token("testToken", "TT", INITIAL_MINT);
        exchange = new Exchange(address(token));
        token.transfer(address(user), TOKEN_AMOUNT);
        token.transfer(address(user2), TOKEN_AMOUNT);
        vm.stopPrank();
    }

    function testAddLiquidity() public {
        vm.startPrank(deployer);
        token.approve(address(exchange), TOKEN_AMOUNT);
        exchange.addLiquidity{value: INITIAL_LIQUIDITY}(TOKEN_AMOUNT);
        vm.stopPrank();

        assertEq(address(exchange).balance, INITIAL_LIQUIDITY);
        assertEq(exchange.getReserve(), TOKEN_AMOUNT);
    }

    function testGetPrice() public {
        vm.startPrank(user);
        token.approve(address(exchange), TOKEN_AMOUNT);
        exchange.addLiquidity{value: USER_LIQUIDITY}(TOKEN_AMOUNT);

        uint256 tokenReserve = exchange.getReserve();
        uint256 etherReserve = address(exchange).balance;

        // ETH per token
        assertEq(exchange.getPrice(etherReserve, tokenReserve), 500);

        // token per eth
        assertEq(exchange.getPrice(tokenReserve, etherReserve), 2000);
    }

    function testGetTokenAmount() public {
        vm.startPrank(user);
        token.approve(address(exchange), TOKEN_AMOUNT);
        exchange.addLiquidity{value: USER_LIQUIDITY}(TOKEN_AMOUNT);
        
        //TODO work on how to convert wei back to ether
        uint tokensOut = exchange.getTokenAmount(1 ether);
        console.log(tokensOut);
        assertEq(vm.toString(tokensOut), "1.998001998001998001");

        tokensOut = exchange.getTokenAmount(100 ether);
        console.log(tokensOut);
        assertEq(vm.toString(tokensOut), "181.818181818181818181");

        tokensOut = exchange.getTokenAmount(1000 ether);
        console.log(tokensOut);
        assertEq(vm.toString(tokensOut), "1000.0");
    }

    function testGetETHAmount() public {
        vm.startPrank(user);
        token.approve(address(exchange), TOKEN_AMOUNT);
        exchange.addLiquidity{value: USER_LIQUIDITY}(TOKEN_AMOUNT);
        
        uint ethOut = exchange.getTokenAmount(2 ether);
        console.log(ethOut);
        assertEq(vm.toString(ethOut), "0.999000999000999");

        ethOut = exchange.getTokenAmount(100 ether);
        console.log(ethOut);
        assertEq(vm.toString(ethOut), "47.619047619047619047");

        ethOut = exchange.getTokenAmount(2000 ether);
        console.log(ethOut);
        assertEq(vm.toString(ethOut), "500.0");
    }
}
