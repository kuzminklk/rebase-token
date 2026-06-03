


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
Layout of functions: (in practice here)
1. Interest Rate
2. Balance
3. Mint
4. Burn
5. Transfer
6. Roles
*/



// SPDX-License-Identifier: MIT  

pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";



/**
 * @notice Token with flexible supply and cross-chain functionality via CCIP
 */
contract Token is ERC20, Ownable, AccessControl {

	error Token__InterestRateCanOnlyDecrease(uint256 previousInterestRate, uint256 newInterestRate);

	bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
	uint256 private constant PRECISION = 1e18;
	uint256 public s_interestRate = (5 * PRECISION) / 1e8;
	mapping(address account => uint256 interestRate) public s_accountToInterestRate;
	mapping(address account => uint256 lastUpdatedTimestamp) private s_accountToLastUpdatedTimestamp;

	event InterestRateSet(uint256 indexed newInterestRate);

	constructor() ERC20("Rebase Token", "TOKEN") Ownable(msg.sender) {
	}	


	// — Interest Rate —

	/**
	 * @notice Set new interest rate
	 * @dev Interest rate can only decrease
	 */
	function setInterestRate(uint256 _interestRate) external onlyOwner {
		if (_interestRate >= s_interestRate) {
			revert Token__InterestRateCanOnlyDecrease(s_interestRate, _interestRate);
		}
		s_interestRate = _interestRate;
		emit InterestRateSet(_interestRate);
	}

	/**
	 * @return interestRate Interest rate with 1e18 percision 
	 */
	function _calculateAccountAccumulatedInterestRate(address _account) private view returns (uint256) {
		uint256 timeElapsed = block.timestamp - s_accountToLastUpdatedTimestamp[_account];
		return PRECISION + (s_accountToInterestRate[_account] * timeElapsed);
	}


	// — Balance —

	/**
	 * @return balance Balance of account with 1e18 percision
	 */
	function balanceOf(address _account) public override view returns (uint256) {
		return (super.balanceOf(_account) * _calculateAccountAccumulatedInterestRate(_account)) / PRECISION;
	}

	function principleBalanceOf(address _user) external view returns (uint256) {
		return super.balanceOf(_user);
	}


	// — Mint —

	function mint(address _to, uint256 _amount, uint256 _interestRate) external mintAccruedInterest(_to) onlyRole(MINT_AND_BURN_ROLE) {
		if (_interestRate == 0) {
			_interestRate = s_interestRate;
		}
		_mint(_to, _amount);
		s_accountToInterestRate[_to] = _interestRate;
	}

	/**
	 * @notice Mint accured insterest when user mint, burn or transfer
	 */
	modifier mintAccruedInterest(address _account) {
		uint256 principleBalance = super.balanceOf(_account);
		uint256 balance = balanceOf(_account);
		uint256 difference = balance - principleBalance;
		s_accountToLastUpdatedTimestamp[_account] = block.timestamp;
		_mint(_account, difference);
		_;
	}


	// — Burn —

	function burn(address _from, uint256 _amount) external mintAccruedInterest(_from) onlyRole(MINT_AND_BURN_ROLE) {
		if (_amount == type(uint256).max) {
			_amount = balanceOf(_from);
		}
		_burn(_from, _amount);
	}


	// — Transfer —

	function transfer(address _to, uint256 _amount) public override mintAccruedInterest(msg.sender) mintAccruedInterest(_to) returns (bool) {
		if (_amount == type(uint256).max) {
			_amount = balanceOf(msg.sender);
		}
		if (balanceOf(_to) == 0) {
			s_accountToInterestRate[_to] = s_accountToInterestRate[msg.sender];
		}
		return super.transfer(_to, _amount);
	}

	function transferFrom(address _from, address _to, uint256 _amount) public override mintAccruedInterest(_from) mintAccruedInterest(_to) returns (bool) {
		if (_amount == type(uint256).max) {
			_amount = balanceOf(_from);
		}
		if (balanceOf(_to) == 0) {
			s_accountToInterestRate[_to] = s_accountToInterestRate[_from];
		}
		return super.transferFrom(_from, _to, _amount);
	}


	// — Roles —

	function grantMintAndBurnRole(address _account) external onlyOwner {
		_grantRole(MINT_AND_BURN_ROLE, _account);
	} 
}