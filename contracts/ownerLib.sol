// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

library OwnerLibrary {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct OwnerStorage {
        EnumerableSet.AddressSet supportedOwners;
    }

    event AddOwner(address indexed Owner);
    event RemoveOwner(address indexed Owner);

    function addOwner(OwnerStorage storage storageData, address Owner) internal {
        require(storageData.supportedOwners.add(address(Owner)), "YourContract: already supported");
        emit AddOwner(address(Owner));
    }

    function removeOwner(OwnerStorage storage storageData, address Owner) internal {
        storageData.supportedOwners.remove(address(Owner));
        emit RemoveOwner(address(Owner));
    }

    function quantityOwner(OwnerStorage storage storageData) internal view returns (uint256) {
        return storageData.supportedOwners.length();
    }

    function valueOwner(OwnerStorage storage storageData) internal view returns (address[] memory) {
        uint256 length = storageData.supportedOwners.length();
        address[] memory tokens = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            tokens[i] = storageData.supportedOwners.at(i);
        }
        return tokens;
    }

    function isOwnerSupported(OwnerStorage storage storageData, address Owner) internal view returns (bool) {
        return storageData.supportedOwners.contains(address(Owner));
    }

    modifier onlySupportedOwner(OwnerStorage storage storageData, address Owner) {
        require(isOwnerSupported(storageData, Owner), "YourContract: unsupported payment token");
        _;
    }
}