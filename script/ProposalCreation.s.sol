// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {AaveGovernanceV2, IExecutorWithTimelock} from 'aave-address-book/AaveGovernanceV2.sol';

library DeployL1Proposal {
  function _deployL1Proposal(address payload, bytes32 ipfsHash)
    internal
    returns (uint256 proposalId)
  {
    require(payload != address(0), "ERROR: PAYLOAD can't be address(0)");
    require(ipfsHash != bytes32(0), "ERROR: IPFS_HASH can't be bytes32(0)");
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

contract DeployENS is Script {
  function run() external {
    vm.startBroadcast();
    DeployL1Proposal._deployL1Proposal(
      0xf42D0a1b03C0795021272a4793CD03dCb97581D3,
      0x54f91e12ea75ccaf9101fa8d59bf08b9edab7a745f16ca0ac26b668e47b93952
    );
    vm.stopBroadcast();
  }
}
