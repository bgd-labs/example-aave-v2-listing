// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console.sol';
import 'forge-std/Script.sol';
import {ENSListingPayload} from 'src/contracts/ENSListingPayload.sol';

contract DeployENSListingPayload is Script {
    function run() public {
        vm.startBroadcast();

        address ensListingPayload = address(new ENSListingPayload());
        console.log('ENS Listing Payload address', ensListingPayload);

        vm.stopBroadcast();
    }
}