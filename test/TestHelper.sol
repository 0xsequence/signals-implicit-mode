// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

contract TestHelper {

  function _hashUrl(
    string memory url
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(url));
  }

  function _projectId(bytes12 projectIdUpper, address owner) internal pure returns (bytes32 projectId) {
    projectId = bytes32(abi.encodePacked(projectIdUpper, owner));
  }

  function _deduplicateBytes32Array(
    bytes32[] memory array
  ) internal pure returns (bytes32[] memory deduplicatedArray) {
    deduplicatedArray = new bytes32[](array.length);
    uint256 deduplicatedIndex;
    for (uint256 i; i < array.length; i++) {
      bool isDuplicate;
      for (uint256 j; j < deduplicatedIndex; j++) {
        if (deduplicatedArray[j] == array[i]) {
          isDuplicate = true;
          break;
        }
      }
      if (!isDuplicate) {
        deduplicatedArray[deduplicatedIndex++] = array[i];
      }
    }
    assembly {
      mstore(deduplicatedArray, deduplicatedIndex)
    }
  }

  function _deduplicateStringArray(
    string[] memory array
  ) internal pure returns (string[] memory deduplicatedArray) {
    deduplicatedArray = new string[](array.length);
    uint256 deduplicatedIndex;
    for (uint256 i; i < array.length; i++) {
      bool isDuplicate;
      bytes32 currentHash = _hashUrl(array[i]);
      for (uint256 j; j < deduplicatedIndex; j++) {
        if (currentHash == _hashUrl(deduplicatedArray[j])) {
          isDuplicate = true;
          break;
        }
      }
      if (!isDuplicate) {
        deduplicatedArray[deduplicatedIndex++] = array[i];
      }
    }
    assembly {
      mstore(deduplicatedArray, deduplicatedIndex)
    }
  }

}
