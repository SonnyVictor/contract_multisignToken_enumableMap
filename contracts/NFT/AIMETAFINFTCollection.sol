// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

library Counters {
    struct Counter {
        uint256 _value;
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

error AllNFTsHaveBeenSold();
error DontHaveEnoughFund();
error OnlyOpenSaleTwoPhases();
error AllNFTsHaveBeenSoldInThisPhase();

contract AIMETAFINFTCollection is ERC721, Ownable, ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    string[] internal s_AIMETAFITokenURIs = [
        "ipfs://bafkreiczsnsikyc62taeaefvp5g6oyx4ywfufw3g7bat5r6lu3dgywvb3e", // SuperRare_Ratio Gold
        "ipfs://bafkreihn3uip42z4cww2ajua2ulqwdlviclnw2ihxriawn27su6ojap7qq", // Rare_Ratio Sliver
        "ipfs://bafkreidxcysyg3cinl4wpvm5nkxgxftz2uhbhntefexthkdl6rjozixcqm" // CommonRare_Ratio Bronze
    ];

    uint256 private constant TOTAL_PHASES = 2;

    uint256[TOTAL_PHASES] private superRareCounts = [10, 40]; //Quantity_SuperRare Gold
    uint256[TOTAL_PHASES] private rareCounts = [20, 130]; //Quantity_Rare Silver
    uint256[TOTAL_PHASES] private commonCounts = [30, 270]; //Quantity_CommonRare Bronze

    uint256 private currentPhase = 0;   

    uint256 private priceMintPhases1;
    uint256 private priceMintPhases2;

    uint256 public totalSupply = 500;

    bool private isPhasesOpen1;
    bool private isPhasesOpen2;

    event Mint(address buyer, uint256 tokenId, uint256 time, string tokenURI);

    constructor(
        uint256 _pricePhases1,
        uint256 _pricePhases2
    ) ERC721("AIMETAFI NFT Collection", "AMFINFT") Ownable(msg.sender) {
        priceMintPhases1 = _pricePhases1;
        priceMintPhases2 = _pricePhases2;
    }

    function getRandomNFT(
        uint256 _phases
    ) internal view returns (string memory) {
        uint256 totalQuantity = commonCounts[_phases] +
            rareCounts[_phases] +
            superRareCounts[_phases];
        uint256 randomValue = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    msg.sender,
                    block.prevrandao,
                    blockhash(block.number - 1),
                    gasleft()
                )
            )
        ) % totalQuantity;
        if (
            randomValue < superRareCounts[_phases] &&
            superRareCounts[_phases] > 0
        ) {
            return s_AIMETAFITokenURIs[0]; // SuperRare_URI
        } else if (
            randomValue < superRareCounts[_phases] + rareCounts[_phases] &&
            rareCounts[_phases] > 0
        ) {
            return s_AIMETAFITokenURIs[1]; // Rare_URI
        } else if (commonCounts[_phases] > 0) {
            return s_AIMETAFITokenURIs[2]; // Common_URI
        } else if (superRareCounts[_phases] > 0) {
            return s_AIMETAFITokenURIs[0]; // SuperRare_URI
        } else {
            return s_AIMETAFITokenURIs[1];
        }
    }

    function updateCounts(string memory _tokenURI, uint256 _phases) internal {
        if (
            keccak256(abi.encodePacked(_tokenURI)) ==
            keccak256(abi.encodePacked(s_AIMETAFITokenURIs[2]))
        ) {
            commonCounts[_phases]--;
        } else if (
            keccak256(abi.encodePacked(_tokenURI)) ==
            keccak256(abi.encodePacked(s_AIMETAFITokenURIs[1]))
        ) {
            rareCounts[_phases]--;
        } else if (
            keccak256(abi.encodePacked(_tokenURI)) ==
            keccak256(abi.encodePacked(s_AIMETAFITokenURIs[0]))
        ) {
            superRareCounts[_phases]--;
        }
    }

    function mint(
        uint256 _phases
    )
        external
        payable
        onlyValidPhase(_phases)
        checkOpenOrCloseBothPhases(_phases)
        returns (uint256)
    {
        if (_tokenIds.current() >= totalSupply) revert AllNFTsHaveBeenSold();
        if (msg.value != getPriceMint(_phases)) revert DontHaveEnoughFund();
        if (
            commonCounts[_phases] +
                rareCounts[_phases] +
                superRareCounts[_phases] <
            0
        ) revert AllNFTsHaveBeenSoldInThisPhase();
        if (_phases == 0) {
            require(msg.sender == owner(), "You are not Owner");
            for (uint256 i = 0; i < 60; i++) {
                uint256 newItemId = _tokenIds.current() + 1;
                _tokenIds.increment();
                string memory tokenURITemp = getRandomNFT(_phases);
                _safeMint(msg.sender, newItemId);
                _setTokenURI(newItemId, tokenURITemp);
                updateCounts(tokenURITemp, _phases);
                emit Mint(
                    msg.sender,
                    _tokenIds.current(),
                    block.timestamp,
                    tokenURITemp
                );
            }
        } else {
            uint256 newItemId = _tokenIds.current() + 1;
            _tokenIds.increment();
            string memory tokenURITemp = getRandomNFT(_phases);
            _safeMint(msg.sender, newItemId);
            _setTokenURI(newItemId, tokenURITemp);
            updateCounts(tokenURITemp, _phases);
            emit Mint(
                msg.sender,
                _tokenIds.current(),
                block.timestamp,
                tokenURITemp
            );
        }
        bool sent = payable(owner()).send(msg.value);
        require(sent, "Failed to send Ether");

        return _tokenIds.current();
    }

    function sendNFTToAddresses(
        address _user,
        uint256[] calldata amountsIds
    ) external onlyOwner {
        require(amountsIds.length > 0, "Amounts or IDs array is empty");
        require(
            balanceOf(msg.sender) >= amountsIds.length,
            "Not enough NFTs to transfer"
        );
        for (uint256 i = 0; i < amountsIds.length; i++) {
            _safeTransfer(msg.sender, _user, amountsIds[i]);
        }
    }

    function getNFTBalance(address owner) internal view returns (uint256) {
        require(owner != address(0), "Invalid address");
        return balanceOf(owner);
    }

    function setPriceMintPhase(
        uint256 _phases,
        uint256 _price
    ) external onlyOwner {
        if (_phases == 0) {
            priceMintPhases1 = _price;
        } else if (_phases == 1) {
            priceMintPhases2 = _price;
        } else {
            revert OnlyOpenSaleTwoPhases();
        }
    }

    function getPriceMint(uint256 _phases) internal view returns (uint256) {
        if (_phases == 0) {
            return priceMintPhases1;
        } else if (_phases == 1) {
            return priceMintPhases2;
        } else {
            revert OnlyOpenSaleTwoPhases();
        }
    }

    function getPriceMintPhases1() external view returns (uint256) {
        return priceMintPhases1;
    }

    function getPriceMintPhase2() external view returns (uint256) {
        return priceMintPhases2;
    }

    function CheckOpenPhases1() external view returns (bool) {
        return isPhasesOpen1;
    }

    function CheckOpenPhases2() external view returns (bool) {
        return isPhasesOpen2;
    }

    function getAmountRemainingMintPhases1() external view returns (uint256) {
        return commonCounts[0] + rareCounts[0] + superRareCounts[0];
    }

    function getAmountRemainingMintPhases2() external view returns (uint256) {
        return commonCounts[1] + rareCounts[1] + superRareCounts[1];
    }

    function getCurrentPhase() external view returns (uint256) {
        return currentPhase;
    }

    function tokenId() external view returns (uint256) {
        return _tokenIds.current();
    }

    function openmint(uint256 _phases, bool _openorclose) external onlyOwner {
        if (_phases == 0) {
            isPhasesOpen1 = _openorclose;
        } else if (_phases == 1) {
            isPhasesOpen2 = _openorclose;
        }
    }

    modifier onlyValidPhase(uint256 _phases) {
        require(_phases < TOTAL_PHASES, "Invalid phase");
        _;
    }
    modifier checkOpenOrCloseBothPhases(uint256 _phases) {
        require(
            (_phases == 0 && isPhasesOpen1) || (_phases == 1 && isPhasesOpen2),
            "The phase is not opened yet"
        );
        _;
    }

    function tokenURI(
        uint256 _tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(_tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}