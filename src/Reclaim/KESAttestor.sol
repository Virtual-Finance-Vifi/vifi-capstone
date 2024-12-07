// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./Addresses.sol";

interface IReclaim {
    function verifyProof(bytes memory proof) external returns (string memory);

    function extractFieldFromContext(
        string memory data,
        string memory target
    ) external pure returns (string memory);
}

contract KESAttestor {
    // Address of the external contract
    address public reclaimAddress;

    struct LatestAttestation {
        string date;
        string currency;
        string price;
    }

    LatestAttestation public latestAttestation;

    constructor(address _reclaimAddress) {
        reclaimAddress = _reclaimAddress;
    }

    /**
     * @dev Calls the `verifyProof` function of the external contract.
     * @param proof The proof data to be sent to `verifyProof`.
     * @return success Boolean indicating if the proof was successfully verified.
     */
    function callVerifyProof(bytes memory proof) public returns (bool success) {
        IReclaim reclaim = IReclaim(reclaimAddress);
        string memory context = reclaim.verifyProof(proof);
        latestAttestation = parseDataField(context);
        success = true;
    }

    /**
     * @dev Extracts the `data` field, parses it, and returns the latest attestation.
     * @param data The proof data in JSON-like format.
     * @return attestation The latest attestation.
     */
    function parseDataField(
        string memory data
    ) private view returns (LatestAttestation memory attestation) {
        IReclaim reclaim = IReclaim(reclaimAddress);

        // Extract the "data" field
        string memory extractedData = reclaim.extractFieldFromContext(
            data,
            "data"
        );

        // Example format: "[[\"04\\/12\\/2024\",\"US DOLLAR\",\"129.5931\"]]"
        bytes memory extractedBytes = bytes(extractedData);

        attestation = LatestAttestation(
            parseValue(extractedBytes, 0),
            parseValue(extractedBytes, 1),
            parseValue(extractedBytes, 2)
        );
    }

    /**
     * @dev Helper function to parse a specific value from the nested array.
     * @param dataBytes The byte representation of the extracted data.
     * @param index The index of the field to extract (0 = date, 1 = currency, 2 = price).
     * @return value The extracted value as a string.
     */
    function parseValue(
        bytes memory dataBytes,
        uint256 index
    ) internal pure returns (string memory value) {
        uint256 startIndex;
        uint256 endIndex;

        // Traverse the dataBytes to locate the value at the specified index
        uint256 count = 0;
        for (uint256 i = 0; i < dataBytes.length; i++) {
            if (dataBytes[i] == '"') {
                if (count == index) {
                    startIndex = i + 1;
                } else if (count == index + 1) {
                    endIndex = i;
                    break;
                }
                count++;
            }
        }

        require(endIndex > startIndex, "Invalid format or index");
        value = string(slice(dataBytes, startIndex, endIndex));
    }

    /**
     * @dev Helper function to slice bytes data.
     * @param data The byte array.
     * @param start The start index.
     * @param end The end index.
     * @return result The sliced byte array as a string.
     */
    function slice(
        bytes memory data,
        uint256 start,
        uint256 end
    ) internal pure returns (bytes memory result) {
        result = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = data[i];
        }
    }
}
