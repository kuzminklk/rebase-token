


/* 
Layout of Smart-Contract: (in theory and in practice here)
1. Version
2. Imports
3. Interfaces, Libraries, Contracts
4. Errors
5. Types
6. State Variables
7. Events
8. Modifiers
9. Funcitons
*/

/* 
Layout of functions: (in theory)
1. Constructor
2. Recive Function
3. Fallback function
4. Public
5. Private
6. View, Pure
*/

/* 
Layout of test sections:
1. Interest Rate
2. Balance
3. Mint
4. Burn
5. Transfer
6. Roles
*/



// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { console, Test } from "forge-std/Test.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import { Token } from "../src/Token.sol";
import { Vault } from "../src/Vault.sol";
import { IToken } from "../src/interfaces/IToken.sol";


/**
 * @notice Test token functionality
 */
contract TestToken is Test {

	address public OWNER = makeAddr("OWNER");
	uint256 public OWNER_INITIAL_BALANCE = 100 ether;
	address public USER_1 = makeAddr("USER_1");
	address public USER_2 = makeAddr("USER_2");
	uint256 public USER_1_INITIAL_BALANCE = 10 ether;
	uint256 public USER_2_INITIAL_BALANCE = 10 ether;
	uint256 public VAULT_INITIAL_BALANCE = 10 ether;

	uint256 private constant PRECISION = 1e18;
	uint256 public INITIAL_INTEREST_RATE = (5 * PRECISION) / 1e8;
	uint256 public ALTERNATIVE_INTEREST_RATE = (3 * PRECISION) / 1e8;

	Token private token;
	Vault private vault;

	function setUp() public {
		vm.deal(OWNER, OWNER_INITIAL_BALANCE);
		vm.deal(USER_1, USER_1_INITIAL_BALANCE);
		vm.deal(USER_2, USER_2_INITIAL_BALANCE);
		vm.startPrank(OWNER);
			token = new Token();
			vault = new Vault(IToken(address(token)));
			token.grantMintAndBurnRole(address(vault));
			payable(address(vault)).call{value: VAULT_INITIAL_BALANCE}("");
		vm.stopPrank();
	}


	// — Interest Rate —

	function testInterestRate(uint256 amount) public {
		uint256 boundedAmount = bound(amount, 1 gwei, 1 ether);
		vm.startPrank(USER_1);
			vault.deposit{value: boundedAmount}();
			uint256 startingBalance = token.balanceOf(USER_1);
			assertEq(boundedAmount, startingBalance);
			vm.warp(block.timestamp + 1 hours);
			uint256 middleBalance = token.balanceOf(USER_1);
			assertGt(middleBalance, startingBalance);
			vm.warp(block.timestamp + 1 hours);
			uint256 finalBalance = token.balanceOf(USER_1);
			assertGt(finalBalance, middleBalance);

			assertApproxEqAbs(finalBalance - middleBalance, middleBalance - startingBalance, 1);
		vm.stopPrank();
	}

	function testNotOwnerCannotSetInterestRate() public {
		vm.startPrank(USER_1);
			vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
			token.setInterestRate(ALTERNATIVE_INTEREST_RATE);
		vm.stopPrank();
	}


	// — Mint —

	function testCannotMintWithoutRole(uint256 amount) public {
		uint256 boundedAmount = bound(amount, 1 gwei, 1 ether);
		vm.startPrank(OWNER);
			uint256 interestRate = token.s_interestRate();
			vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
			token.mint(msg.sender, boundedAmount, interestRate);
		vm.stopPrank();
	}


	// — Burn —

	function testCannotBurnWithoutRole(uint256 amount) public {
		uint256 boundedAmount = bound(amount, 1 gwei, 1 ether);
		vm.startPrank(OWNER);
			vault.deposit{value: boundedAmount}();
			vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
			token.burn(msg.sender, boundedAmount);
		vm.stopPrank();
	}


	// — Transfer —

	function testRedeem(uint256 amount) public {
		uint256 boundedAmount = bound(amount, 1 gwei, 1 ether);
		vm.startPrank(USER_1);
			vault.deposit{value: boundedAmount}();
			uint256 startingBalance = token.balanceOf(USER_1);
			assertEq(boundedAmount, startingBalance);
			vault.redeem(type(uint256).max);

			assertEq(token.balanceOf(USER_1), 0);
			assertEq(address(USER_1).balance, USER_1_INITIAL_BALANCE);
		vm.stopPrank();
	}

	function testRedeemAfterTimePassed(uint256 amount, uint256 time) public {
		uint256 boundedAmount = bound(amount, 1 gwei, 1 ether);
		uint256 boundedTime = bound(time, 1, type(uint96).max);
		vm.startPrank(USER_1);
			vault.deposit{value: boundedAmount}();
			uint256 startingBalance = token.balanceOf(USER_1);
			assertEq(boundedAmount, startingBalance);

			vm.warp(block.timestamp + boundedTime);
			uint256 increasedBalance = token.balanceOf(USER_1);
			vm.deal(address(vault), increasedBalance);
			vault.redeem(type(uint256).max);

			assertEq(token.balanceOf(USER_1), 0);
			assertEq(address(USER_1).balance, USER_1_INITIAL_BALANCE + (increasedBalance - startingBalance));
		vm.stopPrank();
	}

	function testTransfer(uint256 amount) public {
		uint256 boundedAmount = bound(amount, 1 gwei, 1 ether);
		vm.startPrank(USER_1);
			vault.deposit{value: boundedAmount}();
		vm.stopPrank();

		vm.startPrank(OWNER);
			token.setInterestRate(ALTERNATIVE_INTEREST_RATE);
		vm.stopPrank();

		vm.startPrank(USER_1);
			token.transfer(USER_2, boundedAmount);
			assertEq(token.balanceOf(USER_2), boundedAmount);
			assertEq(token.s_accountToInterestRate(USER_2), INITIAL_INTEREST_RATE);
		vm.stopPrank();
	}
}