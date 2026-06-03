

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { console, Test } from "forge-std/Test.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { RegistryModuleOwnerCustom } from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import { TokenAdminRegistry } from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/TokenAdminRegistry.sol";
import { RateLimiter } from "@chainlink/contracts-ccip/contracts/libraries/RateLimiter.sol";
import { Client } from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import { IRouterClient } from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import { TokenPool } from "@chainlink/contracts-ccip/contracts/pools/TokenPool.sol";
import { CCIPLocalSimulatorFork, Register } from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";

import { Token } from "../src/Token.sol";
import { Vault } from "../src/Vault.sol";
import { CustomTokenPool } from "../src/CustomTokenPool.sol";


contract Deploy is Script {
	
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

	// Network details
	Register.NetworkDetails public sepoliaNetworkDetails;
	Register.NetworkDetails public baseSepoliaNetworkDetails;

	// Forks
	uint256 public SEPOLIA_FORK;
	uint256 public BASE_SEPOLIA_FORK;

	// Amounts
	uint256 public VAULT_INITIAL_BALANCE = 10000000 gwei; // 0.01 ether

	function run() public {
		deploy();
	}

	function deploy() public {
		// Create Forks
		SEPOLIA_FORK = vm.createFork("sepolia");
		BASE_SEPOLIA_FORK = vm.createFork("base-sepolia");

		// Get networks details
		vm.selectFork(SEPOLIA_FORK);
		sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
		vm.selectFork(BASE_SEPOLIA_FORK);
		baseSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);


		// — Sepolia Deployment —

		// Deploy Token, Vault, Pool for Sepolia
		vm.selectFork(SEPOLIA_FORK);

		vm.startBroadcast(msg.sender);
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
		vm.stopBroadcast();


		// — Base Sepolia Deployment —

		vm.selectFork(BASE_SEPOLIA_FORK);

		// Deploy Token, Pool Base Sepolia
		vm.startBroadcast(msg.sender);
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
		vm.stopBroadcast();
	}
}