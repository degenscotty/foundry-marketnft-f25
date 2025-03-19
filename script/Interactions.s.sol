// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {MarketNft} from "src/MarketNft.sol";

contract MintPropertyNft is Script {
    string tokenUri = "ipfs://example-uri";
    string propertyName = "Beach House";
    string propertyDesc = "Beautiful property on the beach";
    string propertyLoc = "Miami, FL";

    function run() external {
        address mostRecentlyDeployedMarketNft = DevOpsTools.get_most_recent_deployment(
            "MarketNft",
            block.chainid
        );
        mintNftOnContract(mostRecentlyDeployedMarketNft);
    }

    function mintNftOnContract(address contractAddress) public {
        vm.startBroadcast();
        MarketNft(payable(contractAddress)).mintNft(propertyName, propertyDesc, propertyLoc, tokenUri, 1000);
        vm.stopBroadcast();
    }
}