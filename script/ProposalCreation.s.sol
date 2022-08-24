// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {AaveGovernanceV2, IExecutorWithTimelock} from 'aave-address-book/AaveGovernanceV2.sol';

contract DeployL1Proposal is Script {
  address internal constant PAYLOAD = address(0); // TODO: add here deployed payload address
  bytes32 internal constant IPFS_HASH = bytes32(0); // TODO: add here proposal ipfs hash

  function run() external {
    require(L2_PAYLOAD != address(0), "ERROR: PAYLOAD can't be address(0)");
    require(IPFS_HASH != bytes32(0), "ERROR: IPFS_HASH can't be bytes32(0)");

    vm.startBroadcast();
    address[] memory targets = new address[](1);
    targets[0] = PAYLOAD;
    uint256[] memory values = new uint256[](1);
    values[0] = 0;
    string[] memory signatures = new string[](1);
    signatures[0] = 'execute()';
    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = '';
    bool[] memory withDelegatecalls = new bool[](1);
    withDelegatecalls[0] = true;

    AaveGovernanceV2.GOV.create(
      IExecutorWithTimelock(AaveGovernanceV2.SHORT_EXECUTOR),
      targets,
      values,
      signatures,
      calldatas,
      withDelegatecalls,
      IPFS_HASH
    );

    vm.stopBroadcast();
  }
}
