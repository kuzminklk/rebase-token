


/* 
Layout of Smart-Contract:
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
Layout of functions:
1. Constructor
2. Recive Function
3. Fallback function
4. Public
5. Private
6. View, Pure
*/



// SPDX-License-Identifier: MIT  

pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import { Token } from "./Token.sol";
import { IToken } from "./interfaces/IToken.sol";



/**
 * @notice Vault that takes deposits and rule Token mint and burn
 */
contract Vault {
	error Vault__TranferFailed();

	IToken public immutable i_token;

	event Deposited(address indexed to, uint256 amount);

	constructor(IToken _token) {
		i_token = _token;
	}
	
	receive() external payable {}

	function deposit() external payable {
		uint256 interestRate = i_token.s_accountToInterestRate(msg.sender);
		i_token.mint(msg.sender, msg.value, interestRate);
		emit Deposited(msg.sender, msg.value);
	}

	function redeem(uint256 _amount) external {
		if (_amount == type(uint256).max) {
			_amount = i_token.balanceOf(msg.sender);
		}
		i_token.burn(msg.sender, _amount);
		(bool success, ) = payable(msg.sender).call{value: _amount}("");
		if (!success) {
			revert Vault__TranferFailed();
		}
	}

}