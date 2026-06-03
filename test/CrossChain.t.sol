


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
4. public
5. public
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
import { IERC20 } from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";
import { RegistryModuleOwnerCustom } from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import { TokenAdminRegistry } from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/TokenAdminRegistry.sol";
import { RateLimiter } from "@chainlink/contracts-ccip/contracts/libraries/RateLimiter.sol";
import { Client } from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import { IRouterClient } from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import { TokenPool } from "@chainlink/contracts-ccip/contracts/pools/TokenPool.sol";
import { CCIPLocalSimulatorFork, Register } from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";

import { Token } from "../src/Token.sol";
import { Vault } from "../src/Vault.sol";
import { IToken } from "../src/interfaces/IToken.sol";
import { CustomTokenPool } from "../src/CustomTokenPool.sol";



/**
 * @notice Test cross-chain (Chainlink CCIP) functionality
 * @dev Set up local chainlink CCIP simulator via “CCIPLocalSimulatorFork”, …
 */
contract TestCrossChain is Test {

	// Users and balances
	address public OWNER = makeAddr("OWNER");
	uint256 public OWNER_INITIAL_BALANCE = 100 ether;
	address public USER_1 = makeAddr("USER_1");
	address public USER_2 = makeAddr("USER_2");
	uint256 public USER_1_INITIAL_BALANCE = 10 ether;
	uint256 public USER_2_INITIAL_BALANCE = 10 ether;
	uint256 public VAULT_INITIAL_BALANCE = 10 ether;
	uint256 public TOKEN_POOL_INITIAL_BALANCE = 10 ether;

	// Percision
	uint256 public constant PRECISION = 1e18;

	// Interest rates
	uint256 public INITIAL_INTEREST_RATE = (5 * PRECISION) / 1e8;
	uint256 public ALTERNATIVE_INTEREST_RATE = (3 * PRECISION) / 1e8;

	// Contracts
	Token public sepoliaToken;
	Token public baseSepoliaToken;
	Vault public sepoliaVault;
	Vault public baseSepoliaVault;
	CustomTokenPool public sepoliaCustomTokenPool;
	CustomTokenPool public baseSepoliaCustomTokenPool;

	// Network details
	Register.NetworkDetails public sepoliaNetworkDetails;
	Register.NetworkDetails public baseSepoliaNetworkDetails;

	// Forks
	uint256 public SEPOLIA_FORK;
	uint256 public BASE_SEPOLIA_FORK;

	CCIPLocalSimulatorFork public ccipLocalSimulatorFork;


	/**
	 * @notice Do set up, deploy all chainlink-local stuff
	 */
	function setUp() public {
		// Create Forks
		SEPOLIA_FORK = vm.createFork("sepolia");
		BASE_SEPOLIA_FORK = vm.createFork("base-sepolia");

		// Create ccipLocalSimulatorFork and make persistent across Forks
		vm.selectFork(SEPOLIA_FORK);
		ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
		vm.makePersistent(address(ccipLocalSimulatorFork));

		// Get networks details
		vm.selectFork(SEPOLIA_FORK);
		sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
		vm.selectFork(BASE_SEPOLIA_FORK);
		baseSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);


		// — Sepolia Deployment —

		// Fund Owner and Users for Sepolia
		vm.selectFork(SEPOLIA_FORK);
		vm.deal(OWNER, OWNER_INITIAL_BALANCE);
		vm.deal(USER_1, USER_1_INITIAL_BALANCE);
		vm.deal(USER_2, USER_2_INITIAL_BALANCE);
		ccipLocalSimulatorFork.requestLinkFromFaucet(USER_1, USER_1_INITIAL_BALANCE);
		ccipLocalSimulatorFork.requestLinkFromFaucet(USER_2, USER_2_INITIAL_BALANCE);

		// Deploy Token, Vault, Pool for Sepolia
		vm.selectFork(SEPOLIA_FORK);
		vm.startPrank(OWNER);
			// Deploy Token and Vault
			sepoliaToken = new Token();
			sepoliaVault = new Vault(IToken(address(sepoliaToken)));
			// Grant a Role for Vault
			sepoliaToken.grantMintAndBurnRole(address(sepoliaVault));
			// Fund the Vault with Ether
			payable(address(sepoliaVault)).call{value: VAULT_INITIAL_BALANCE}("");
			// Deploy Custom Token Pool
			sepoliaCustomTokenPool = new CustomTokenPool(IERC20(address(sepoliaToken)), new address[](0), sepoliaNetworkDetails.rmnProxyAddress, sepoliaNetworkDetails.routerAddress);
			console.log("Deployed a Sepolia Custom Token Pool at", address(sepoliaCustomTokenPool));
			// Grant a Role for Custom Token Pool
			sepoliaToken.grantMintAndBurnRole(address(sepoliaCustomTokenPool));
			// Register Admin Role
			RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(sepoliaToken));
			// Accept Admin Role
			TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaToken));
			// Set Pool for Token
			TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(address(sepoliaToken), address(sepoliaCustomTokenPool));
			console.log("Set a Sepolia Custom Token Pool from TokenAdminRegistry at", TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).getPool(address(sepoliaToken)));
		vm.stopPrank();


		// — Base Sepolia Deployment —

		// Fund Owner and Users for Base Sepolia
		vm.selectFork(BASE_SEPOLIA_FORK);
		vm.deal(OWNER, OWNER_INITIAL_BALANCE);
		vm.deal(USER_1, USER_1_INITIAL_BALANCE);
		vm.deal(USER_2, USER_2_INITIAL_BALANCE);
		ccipLocalSimulatorFork.requestLinkFromFaucet(USER_1, USER_1_INITIAL_BALANCE);
		ccipLocalSimulatorFork.requestLinkFromFaucet(USER_2, USER_2_INITIAL_BALANCE);

		// Deploy Token, Pool Base Sepolia
		vm.selectFork(BASE_SEPOLIA_FORK);
		vm.startPrank(OWNER);
			// Deploy Token
			baseSepoliaToken = new Token();
			// Deploy Custom Token Pool
			baseSepoliaCustomTokenPool = new CustomTokenPool(IERC20(address(baseSepoliaToken)), new address[](0), baseSepoliaNetworkDetails.rmnProxyAddress, baseSepoliaNetworkDetails.routerAddress);
			console.log("Deployed a Base Sepolia Custom Token Pool at", address(baseSepoliaCustomTokenPool));
			// Grant a Role for Custom Token Pool
			baseSepoliaToken.grantMintAndBurnRole(address(baseSepoliaCustomTokenPool));
			// Register Admin Role
			RegistryModuleOwnerCustom(baseSepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(baseSepoliaToken));
			// Accept Admin Role
			TokenAdminRegistry(baseSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(baseSepoliaToken));
			// Set Pool for Token
			TokenAdminRegistry(baseSepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(address(baseSepoliaToken), address(baseSepoliaCustomTokenPool));
			console.log("Set a Base Sepolia Custom Token Pool from TokenAdminRegistry at", TokenAdminRegistry(baseSepoliaNetworkDetails.tokenAdminRegistryAddress).getPool(address(baseSepoliaToken)));
		vm.stopPrank();
	}


	/**
	 * @notice Configure Custom Token Pool
	 */
	function configureTokenPool(uint256 fork, address localPool, address remotePool, address remoteToken, uint64 remoteChainSelector) public {
		vm.selectFork(fork);

		bytes[] memory remotePoolAddresses = new bytes[](1);
		remotePoolAddresses[0] = abi.encode(address(remotePool));

		TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
		chainsToAdd[0] = TokenPool.ChainUpdate({
			remoteChainSelector: remoteChainSelector,
			remotePoolAddresses: remotePoolAddresses,
			remoteTokenAddress: abi.encode(address(remoteToken)),
			outboundRateLimiterConfig: RateLimiter.Config({
				isEnabled: false,
				capacity: 0,
				rate: 0
			}),
			inboundRateLimiterConfig: RateLimiter.Config({
				isEnabled: false,
				capacity: 0,
				rate: 0
			})
		});

		vm.startPrank(OWNER);
			TokenPool(localPool).applyChainUpdates(new uint64[](0), chainsToAdd);
			console.log("Configure Custom Token Pool for Fork:", fork);
			console.log("With localPool:", localPool);
			console.log("With remotePool:", remotePool);
			console.log("With remoteToken:", remoteToken);
		vm.stopPrank();
	}


	/**
	 * @notice Bridge tokens
	 */
	function bridgeTokens(uint256 amount, uint256 localFork, uint256 remoteFork, Register.NetworkDetails memory localNetworkDetails, Register.NetworkDetails memory remoteNetworkDetails, Token localToken, Token remoteToken) public {
		// Generate amounts struct
		Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
		tokenAmounts[0] = Client.EVMTokenAmount({
			token: address(localToken),
			amount: amount
		});

		// Generate message struct
		Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
			receiver: abi.encode(USER_1),
			data: abi.encode(""),
			tokenAmounts: tokenAmounts,
			feeToken: localNetworkDetails.linkAddress,
			extraArgs: Client._argsToBytes(
        Client.GenericExtraArgsV2({
          gasLimit: 500000, // Gas limit for the callback on the destination chain
          allowOutOfOrderExecution: true // Allows the message to be executed out of order relative to other messages from the same sender
        })
      )
		});

		// Calculate and approve fees
		uint256 fee = IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message);
		IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fee);
		IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amount);

		// Send message to the Router
		IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);
		console.log("CCIP message sended from localFork:", localFork);
		console.log("With amounts:", amount);
	}


	/**
	 * @notice Test tokens bridging
	 */
	function testBridgeTokens(uint256 amount) public {


		// — Configure pools —

		vm.selectFork(SEPOLIA_FORK);
		configureTokenPool(SEPOLIA_FORK, address(sepoliaCustomTokenPool), address(baseSepoliaCustomTokenPool), address(baseSepoliaToken), baseSepoliaNetworkDetails.chainSelector);
		vm.selectFork(BASE_SEPOLIA_FORK);
		configureTokenPool(BASE_SEPOLIA_FORK, address(baseSepoliaCustomTokenPool), address(sepoliaCustomTokenPool), address(sepoliaToken), sepoliaNetworkDetails.chainSelector);


		// — Testing —

		vm.selectFork(SEPOLIA_FORK);
		uint256 boundedAmount = bound(amount, 1 gwei, 1 ether);
		console.log("Bounded amount is:", boundedAmount);
		
		vm.startPrank(USER_1);
			sepoliaVault.deposit{value: boundedAmount}();
			bridgeTokens(boundedAmount, SEPOLIA_FORK, BASE_SEPOLIA_FORK, sepoliaNetworkDetails, baseSepoliaNetworkDetails, sepoliaToken, baseSepoliaToken);
			console.log("Tokens Bridged with amount:", boundedAmount);
		vm.stopPrank();

		vm.warp(block.timestamp + 1 hours);
		uint256 localBalanceAfter = sepoliaToken.balanceOf(USER_1);
		console.log("Local balance after Bridging:", localBalanceAfter);
		uint256 localInterestRate = sepoliaToken.s_accountToInterestRate(USER_1);
		assertEq(localBalanceAfter, 0);

		ccipLocalSimulatorFork.switchChainAndRouteMessage(BASE_SEPOLIA_FORK);
		
		vm.selectFork(BASE_SEPOLIA_FORK);
		uint256 remoteBalanceAfter = baseSepoliaToken.balanceOf(USER_1);
		console.log("Remote balance after Bridging:", remoteBalanceAfter);
		uint256 remoteInterestRate = baseSepoliaToken.s_accountToInterestRate(USER_1);
		console.log("Remote interest rate after Bridging:", remoteInterestRate);

		assertEq(remoteBalanceAfter, boundedAmount);
		assertEq(localInterestRate, remoteInterestRate);
	}
}