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
    uint8 public constant CALL_INDEX = 3;

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function send_message(address _contract, uint256 _nft) external {
        // Verify if caller owns NFT

        address caller = msg.sender;

        require(IERC721(_contract).ownerOf(_nft) == caller, "Caller is not the owner of the NFT provided");

        // Send XCM

        bytes[] memory dest_interior = new bytes[](0x000000084D);
        bytes[] memory asset_interior = new bytes[](0x000000084D060000);

        bytes memory call_data = build_call(_contract, _nft);

        XcmTransactorV3(XCM_TRANSACTOR_V3_ADDRESS).transactThroughSignedMultilocation(
            // Destination MultiLocation
            XcmTransactorV3.Multilocation(1, dest_interior),
            // Fee MultiLocation
            XcmTransactorV3.Multilocation(1, asset_interior),
            // Max weight
            XcmTransactorV3.Weight(50000000, 100000),
            // Call
            call_data,
            // Fee amount
            2000000000000,
            // Overall weight
            XcmTransactorV3.Weight(50000000, 100000),
            // Refund
            true
        );
    }

    function build_call(address _contract, uint256 _nft) internal pure returns (bytes memory) {
        bytes memory prefix = new bytes(2);
        prefix[0] = bytes1(PALLET_INDEX);
        prefix[1] = bytes1(CALL_INDEX);

        return bytes.concat(
            prefix,
            abi.encodePacked(COLLECTION_CONTRACT_20, _contract),
            abi.encodePacked(NFT_U256_ID, ScaleCodec.encodeU256(_nft)),
            bytes1(uint8(1))
        );
    }
}
