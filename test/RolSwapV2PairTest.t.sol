// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../src/UniswapV2/RolSwapV2Pair.sol";
import "./mocks/ERC20Mintable.sol";

contract RolSwapV2PairTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    RolSwapV2Pair pair;

    address deployer = makeAddr("deployer");
    address user = makeAddr("user");

    function setUp() public {
        vm.deal(deployer, 1000 ether);
        vm.deal(user, 1000 ether);

        vm.startPrank(deployer);
        token0 = new ERC20Mintable("Token A", "TKNA");
        token1 = new ERC20Mintable("Token B", "TKNB");
        pair = new RolSwapV2Pair(address(token0), address(token1));

        token0.mint(10 ether, address(deployer));
        token1.mint(10 ether, address(deployer));

        token0.mint(10 ether, address(user));
        token1.mint(10 ether, address(user));

        vm.stopPrank();
    }

    function assertReserves(
        uint112 expectedReserve0,
        uint112 expectedReserve1
    ) internal {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, expectedReserve0, "unexpected reserve0");
        assertEq(reserve1, expectedReserve1, "unexpected reserve1");
    }

    function testMintBootstrap() public {
        vm.startPrank(deployer);
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();
        vm.stopPrank();

        assertEq(pair.balanceOf(deployer), 1 ether - 1000);
        assertReserves(1 ether, 1 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testMintWhenTheresLiquidity() public {
        vm.startPrank(user);
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 2 ether);

        pair.mint();

        vm.stopPrank();

        assertEq(pair.balanceOf(user), 3 ether - 1000);
        assertEq(pair.totalSupply(), 3 ether);
        assertReserves(3 ether, 3 ether);
    }

    function testMintUnbalanced() public {
        vm.startPrank(user);
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();
        assertEq(pair.balanceOf(user), 1 ether - 1000);
        assertReserves(1 ether, 1 ether);

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();
        vm.stopPrank();

        assertEq(pair.balanceOf(user), 2 ether - 1000);
        assertReserves(3 ether, 2 ether);
    }

    function testBurn() public {
        vm.startPrank(deployer);
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();
        pair.burn();
        vm.stopPrank();

        assertEq(pair.balanceOf(deployer), 0);
        assertReserves(1000, 1000);
        assertEq(pair.totalSupply(), 1000);
        assertEq(token0.balanceOf(deployer), 10 ether - 1000);
        assertEq(token1.balanceOf(deployer), 10 ether - 1000);
    }

    function testBurnUnbalanced() public {
        vm.startPrank(deployer);
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();

        pair.burn();
        vm.stopPrank();

        assertEq(pair.balanceOf(deployer), 0);
        assertReserves(1500, 1000);
        assertEq(pair.totalSupply(), 1000);
        assertEq(token0.balanceOf(deployer), 10 ether - 1500);
        assertEq(token1.balanceOf(deployer), 10 ether - 1000);
    }

    function testBurnUnbalancedDifferentUsers() public {
        vm.startPrank(user);
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();

        assertEq(pair.balanceOf(deployer), 0);
        assertEq(pair.balanceOf(user), 1 ether - 1000);
        assertEq(pair.totalSupply(), 1 ether);

        vm.stopPrank();

        vm.startPrank(deployer);
        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();

        assertEq(pair.balanceOf(deployer), 1 ether);

        pair.burn();
        vm.stopPrank();

        assertEq(pair.balanceOf(deployer), 0);
        assertReserves(1.5 ether, 1 ether);
        assertEq(pair.totalSupply(), 1 ether);
        assertEq(token0.balanceOf(deployer), 10 ether - 0.5 ether);
        assertEq(token1.balanceOf(deployer), 10 ether);
    }
}
