// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./interfaces/MoonbeamXcmTransactor.sol";
import "./interfaces/IERC721.sol";

import "./utils/ScaleCodec.sol";

contract Verifier {
    // Collection::Contract20([u8; 20])
    bytes1 internal constant COLLECTION_CONTRACT_20 = 0x01;
    // Nft::U256Id(U256)
    bytes1 internal constant NFT_U256_ID = 0x01;
    // NftOrigins Pallet in Tinkernet
    uint8 public constant PALLET_INDEX = 74;
    // dispatch_registered_call_as_nft call in NftOrigins Pallet
    uint8 public constant CALL_INDEX = 1;
    // Index for VoteInMultisig registered call
    uint8 public constant VOTE_CALL_INDEX = 0;
    // Index for WithdrawVoteInMultisig registered call
    uint8 public constant WITHDRAW_VOTE_CALL_INDEX = 1;
    // Index for OperateMultisig registered call
    uint8 public constant OPERATE_CALL_INDEX = 2;

    address public owner;

    XcmTransactorV3.Multilocation internal xcmTransactorDestination;
    XcmTransactorV3.Multilocation internal xcmTransactorFeeAsset;

    constructor() {
        owner = msg.sender;

        bytes[] memory destInterior = new bytes[](1);
        destInterior[0] = bytes.concat(hex"00", bytes4(uint32(2125)));
        xcmTransactorDestination = XcmTransactorV3.Multilocation({
            parents: 1,
            interior: destInterior
        });

        bytes[] memory assetInterior = new bytes[](2);
        assetInterior[0] = bytes.concat(hex"00", bytes4(uint32(2125)));
        assetInterior[1] = bytes.concat(hex"05", abi.encodePacked(uint128(0)));
        xcmTransactorFeeAsset = XcmTransactorV3.Multilocation({
            parents: 1,
            interior: assetInterior
        });
    }

    enum Operation {
        Vote,
        WithdrawVote,
        Operate
    }

    enum FeeAsset {
        TNKR,
        KSM
    }

    struct FeeInfo {
        XcmTransactorV3.Weight transactRequiredWeightAtMost;
        XcmTransactorV3.Weight overallWeight;
        uint256 feeAmount;
    }

    mapping(Operation => FeeInfo) public operationToFeeInfo;

    function setOperationToFeeInfo(
        Operation _operation,
        uint64 _transactRequiredWeightAtMostRefTime,
        uint64 _transactRequiredWeightAtMostProofSize,
        uint64 _overallWeightRefTime,
        uint64 _overallWeightProofSize,
        uint256 _feeAmount
    ) external {
        require(msg.sender == owner);

        operationToFeeInfo[_operation] = FeeInfo(
            XcmTransactorV3.Weight(_transactRequiredWeightAtMostRefTime, _transactRequiredWeightAtMostProofSize),
            XcmTransactorV3.Weight(_overallWeightRefTime, _overallWeightProofSize),
            _feeAmount
        );
    }

    function vote_in_multisig(address _contract, uint256 _nft, uint32 core_id, bytes32 proposal, bool aye) external {
        // Verify if caller owns NFT

        // address caller = msg.sender;

        // require(IERC721(_contract).ownerOf(_nft) == caller, "Caller is not the owner of the NFT provided");

        // Send XCM

        bytes memory call_data = build_vote_call(_contract, _nft, core_id, proposal, aye);

        FeeInfo memory fee_info = operationToFeeInfo[Operation.Vote];

        XcmTransactorV3(XCM_TRANSACTOR_V3_ADDRESS).transactThroughSignedMultilocation(
            // Destination MultiLocation
            xcmTransactorDestination,
            // Fee MultiLocation
            xcmTransactorFeeAsset,
            // Max weight
            fee_info.transactRequiredWeightAtMost,
            // Call
            call_data,
            // Fee amount
            fee_info.feeAmount,
            // Overall weight
            fee_info.overallWeight,
            // Refund
            true
        );
    }

    function withdraw_vote_in_multisig(address _contract, uint256 _nft, uint32 core_id, bytes32 proposal) external {
        // Verify if caller owns NFT

        // address caller = msg.sender;

        // require(IERC721(_contract).ownerOf(_nft) == caller, "Caller is not the owner of the NFT provided");

        // Send XCM

        bytes memory call_data = build_withdraw_vote_call(_contract, _nft, core_id, proposal);

        FeeInfo memory fee_info = operationToFeeInfo[Operation.WithdrawVote];

        XcmTransactorV3(XCM_TRANSACTOR_V3_ADDRESS).transactThroughSignedMultilocation(
            // Destination MultiLocation
            xcmTransactorDestination,
            // Fee MultiLocation
            xcmTransactorFeeAsset,
            // Max weight
            fee_info.transactRequiredWeightAtMost,
            // Call
            call_data,
            // Fee amount
            fee_info.feeAmount,
            // Overall weight
            fee_info.overallWeight,
            // Refund
            true
        );
    }

    function operate_multisig(address _contract, uint256 _nft, uint32 core_id, FeeAsset fee_asset, bytes memory proposed_call) external {
        // Verify if caller owns NFT

        // address caller = msg.sender;

        // require(IERC721(_contract).ownerOf(_nft) == caller, "Caller is not the owner of the NFT provided");

        // Send XCM

        bytes memory call_data = build_operate_multisig_call(_contract, _nft, core_id, fee_asset, proposed_call);

        FeeInfo memory fee_info = operationToFeeInfo[Operation.Operate];

        XcmTransactorV3(XCM_TRANSACTOR_V3_ADDRESS).transactThroughSignedMultilocation(
            // Destination MultiLocation
            xcmTransactorDestination,
            // Fee MultiLocation
            xcmTransactorFeeAsset,
            // Max weight
            fee_info.transactRequiredWeightAtMost,
            // Call
            call_data,
            // Fee amount
            fee_info.feeAmount,
            // Overall weight
            fee_info.overallWeight,
            // Refund
            true
        );
    }

    function build_vote_call(address _contract, uint256 _nft, uint32 core_id, bytes32 proposal, bool aye) internal pure returns (bytes memory) {
        bytes memory prefix = new bytes(2);
        prefix[0] = bytes1(PALLET_INDEX);
        prefix[1] = bytes1(CALL_INDEX);

        uint8 vote = 0;

        if (aye) vote = 1;

        bytes memory vote_call = bytes.concat(
            bytes1(uint8(VOTE_CALL_INDEX)),
            ScaleCodec.encodeU32(core_id),
            proposal,
            bytes1(uint8(vote))
        );

        return bytes.concat(
            prefix,
            abi.encodePacked(COLLECTION_CONTRACT_20, _contract),
            abi.encodePacked(NFT_U256_ID, ScaleCodec.encodeU256(_nft)),
            vote_call
        );
    }

    function build_withdraw_vote_call(address _contract, uint256 _nft, uint32 core_id, bytes32 proposal) internal pure returns (bytes memory) {
        bytes memory prefix = new bytes(2);
        prefix[0] = bytes1(PALLET_INDEX);
        prefix[1] = bytes1(CALL_INDEX);

        bytes memory withdraw_vote_call = bytes.concat(
            bytes1(uint8(WITHDRAW_VOTE_CALL_INDEX)),
            ScaleCodec.encodeU32(core_id),
            proposal
        );

        return bytes.concat(
            prefix,
            abi.encodePacked(COLLECTION_CONTRACT_20, _contract),
            abi.encodePacked(NFT_U256_ID, ScaleCodec.encodeU256(_nft)),
            withdraw_vote_call
        );
    }

    function build_operate_multisig_call(address _contract, uint256 _nft, uint32 core_id, FeeAsset fee_asset, bytes memory proposed_call) internal pure returns (bytes memory) {
        bytes memory prefix = new bytes(2);
        prefix[0] = bytes1(PALLET_INDEX);
        prefix[1] = bytes1(CALL_INDEX);

        bytes memory operate_multisig_call = bytes.concat(
            bytes1(uint8(OPERATE_CALL_INDEX)),
            ScaleCodec.encodeU32(core_id),
            bytes1(uint8(0)),
            bytes1(uint8(fee_asset)),
            proposed_call
        );

        return bytes.concat(
            prefix,
            abi.encodePacked(COLLECTION_CONTRACT_20, _contract),
            abi.encodePacked(NFT_U256_ID, ScaleCodec.encodeU256(_nft)),
            operate_multisig_call
        );
    }
}
