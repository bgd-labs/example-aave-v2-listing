// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Script.sol';
import {ENSListingPayload} from 'src/contracts/ENSListingPayload.sol';

contract DeployENSListingPayload is Script {
  function run() public {
    vm.startBroadcast();

    new ENSListingPayload(
      0xB2f4Fb41F01CdeF7c10F0e8aFbeB3cFA79d1686F,
      0x2386694b2696015dB1a511AB9cD310e800F93055,
      0x5746b5b6650Dd8d9B1d9D1bbf5E7f23e9761183F
    );

    vm.stopBroadcast();
  }
}
