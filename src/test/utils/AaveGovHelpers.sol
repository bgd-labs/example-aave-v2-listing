// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {VM} from "./VM.sol";

interface IAaveGov {
    struct ProposalWithoutVotes {
        uint256 id;
        address creator;
        address executor;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        bool[] withDelegatecalls;
        uint256 startBlock;
        uint256 endBlock;
        uint256 executionTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool canceled;
        address strategy;
        bytes32 ipfsHash;
    }

    enum ProposalState {
        Pending,
        Canceled,
        Active,
        Failed,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    struct SPropCreateParams {
        address executor;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        bool[] withDelegatecalls;
        bytes32 ipfsHash;
    }

    function create(
        address executor,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        bool[] memory withDelegatecalls,
        bytes32 ipfsHash
    ) external returns (uint256);

    function queue(uint256 proposalId) external;

    function execute(uint256 proposalId) external payable;

    function submitVote(uint256 proposalId, bool support) external;

    function getProposalById(uint256 proposalId)
        external
        view
        returns (ProposalWithoutVotes memory);

    function getProposalState(uint256 proposalId)
        external
        view
        returns (ProposalState);
}

library AaveGovHelpers {
    IAaveGov internal constant GOV =
        IAaveGov(0xEC568fffba86c094cf06b22134B23074DFE2252c);

    address constant SHORT_EXECUTOR =
        0xEE56e2B3D491590B5b31738cC34d5232F378a8D5;

    function _createProposal(
        VM vm,
        address aaveWhale,
        IAaveGov.SPropCreateParams memory params
    ) internal returns (uint256) {
        vm.deal(aaveWhale, 1 ether);
        vm.startPrank(aaveWhale);
        uint256 proposalId = GOV.create(
            params.executor,
            params.targets,
            params.values,
            params.signatures,
            params.calldatas,
            params.withDelegatecalls,
            params.ipfsHash
        );
        vm.stopPrank();
        return proposalId;
    }

    function _passVote(
        VM vm,
        address aaveWhale,
        uint256 proposalId
    ) internal {
        vm.deal(aaveWhale, 1 ether);
        vm.startPrank(aaveWhale);
        vm.roll(block.number + 1);
        GOV.submitVote(proposalId, true);
        uint256 endBlock = GOV.getProposalById(proposalId).endBlock;
        vm.roll(endBlock + 1);
        GOV.queue(proposalId);
        uint256 executionTime = GOV.getProposalById(proposalId).executionTime;
        vm.warp(executionTime + 1);
        GOV.execute(proposalId);
        vm.stopPrank();
    }
}
