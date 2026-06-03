

// SPDX-License-Identifier: MIT  

pragma solidity ^0.8.24;


interface IToken {

/* 	function setInterestRate(uint256 _interestRate) external {}

	function principleBalanceOf(address _user) external view returns (uint256) {}

	function _calculateaccountAccumulatedInterestRate(address _account) private view returns (uint256) {} */

	function s_accountToInterestRate(address _account) external view returns (uint256);

	function balanceOf(address _account) external view returns (uint256);

	function mint(address _to, uint256 _amount, uint256 _interestRate) external;

	function burn(address _from, uint256 _amount) external;

	/* function transfer(address _to, uint256 _amount) external {}

	function transferFrom(address _from, address _to, uint256 _amount) external returns (bool) {} */
}