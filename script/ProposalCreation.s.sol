// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {AaveGovernanceV2, IExecutorWithTimelock} from 'aave-address-book/AaveGovernanceV2.sol';

library DeployL1Proposal {
  function _deployL1Proposal(address payload, bytes32 ipfsHash)
    internal
    returns (uint256 proposalId)
  {
    address[] memory targets = new address[](1);
    targets[0] = payload;
    uint256[] memory values = new uint256[](1);
    values[0] = 0;
    string[] memory signatures = new string[](1);
    signatures[0] = 'execute()';
    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = '';
    bool[] memory withDelegatecalls = new bool[](1);
    withDelegatecalls[0] = true;
    return
      AaveGovernanceV2.GOV.create(
        IExecutorWithTimelock(AaveGovernanceV2.SHORT_EXECUTOR),
        targets,
        values,
        signatures,
        calldatas,
        withDelegatecalls,
        ipfsHash
      );
  }
}

contract DeployX is Script {
  address internal constant PAYLOAD = address(0); // TODO: add here deployed payload address
  bytes32 internal constant IPFS_HASH = bytes32(0); // TODO: add here proposal ipfs hash

  function run() external {
    require(PAYLOAD != address(0), "ERROR: PAYLOAD can't be address(0)");
    require(IPFS_HASH != bytes32(0), "ERROR: IPFS_HASH can't be bytes32(0)");
    vm.startBroadcast();
    DeployL1Proposal._deployL1Proposal(PAYLOAD, IPFS_HASH);
    vm.stopBroadcast();
  }
}
