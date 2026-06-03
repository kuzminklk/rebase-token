


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



// SPDX-License-Identifier: MIT  

pragma solidity ^0.8.24;

import { TokenPool } from "@chainlink/contracts-ccip/contracts/pools/TokenPool.sol";
import { Pool } from "@chainlink/contracts-ccip/contracts/libraries/Pool.sol";
import { IERC20 } from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";

import { IToken } from "./interfaces/IToken.sol";



/**
 * @notice Custom token pool for CCIP (cross-chain) functionality (rules burn and mint)
 */
contract CustomTokenPool is TokenPool {
	uint256 public constant DECIMALS = 1e18;
	uint8 public constant DECIMALS_LENGTH = 18;

	constructor(IERC20 i_token, address[] memory _allowList, address _riskManagmentNetworkProxy, address _router ) TokenPool(i_token, DECIMALS_LENGTH, _allowList, _riskManagmentNetworkProxy, _router) {}

	function lockOrBurn( Pool.LockOrBurnInV1 calldata lockOrBurnIn) override public returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut) {
		_validateLockOrBurn(lockOrBurnIn);
		uint256 accountInterestRate = IToken(address(i_token)).s_accountToInterestRate(lockOrBurnIn.originalSender);
		IToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);

		return lockOrBurnOut = Pool.LockOrBurnOutV1({
			destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
			destPoolData: abi.encode(accountInterestRate)
		});
	}

	function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn) override public returns (Pool.ReleaseOrMintOutV1 memory) {
		_validateReleaseOrMint(releaseOrMintIn, releaseOrMintIn.sourceDenominatedAmount);
		uint256 accountInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
		IToken(address(i_token)).mint(releaseOrMintIn.receiver, releaseOrMintIn.sourceDenominatedAmount, accountInterestRate);

		return Pool.ReleaseOrMintOutV1({
			destinationAmount: releaseOrMintIn.sourceDenominatedAmount
		});
	}
}

