// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
enum IDOStatus {Ongoing,Canceled,Completed}
interface ContractIDO {
    function getAmountUserIDO(uint32 _idIDO, address _address) external view returns (uint256);
    function getIsStatusIDO(uint32 _idIDO)external view returns (IDOStatus);
    function getTotalAmountRaisedListIDO(uint32 _idIDO)external view returns (uint128);
    function getPricePerUnitIDO(uint32 _idIDO) external view returns(uint16);
}
contract distrubuteNFT is  Ownable,ERC1155Holder {
    
    IERC1155 public _tokenContract;

    ContractIDO public idoContract;

    mapping(uint32 idIDO => mapping(address => uint256)) public userClaimed;
    
    constructor(address _idoContractAddress,IERC1155 _addressNFT) Ownable(msg.sender) {
        idoContract = ContractIDO(_idoContractAddress);
        _tokenContract = _addressNFT;
    }

    event NFTDeposited(address indexed depositor, uint256 tokenId, uint256 amount);
    event NFTClaimed(address indexed user, uint32 indexed idIDO, uint256 amountReceived, uint256 timestamp);
    
    function depositNFT(uint128 _tokenId,uint128 _amount) external {
        _tokenContract.safeTransferFrom(msg.sender, address(this), _tokenId, _amount, "0x");
        emit NFTDeposited(msg.sender, _tokenId, _amount);
    }
    

    function claimNFT(uint32 _idIDO) external {
        require(idoContract.getIsStatusIDO(_idIDO) == IDOStatus.Completed, "IDO is not completed");
        uint256 quantityNFT = calculatorReceiveNFT(_idIDO, msg.sender);
        require(userClaimed[_idIDO][msg.sender] < quantityNFT, "You have already claimed enough NFTs or Haven't joined this ido yet");
        require(_tokenContract.balanceOf(address(this),_idIDO) >= quantityNFT,"Not enough NFTs contract");
        userClaimed[_idIDO][msg.sender] =userClaimed[_idIDO][msg.sender]+quantityNFT;
        _tokenContract.safeTransferFrom(address(this), msg.sender, _idIDO, quantityNFT, "0x");
        emit NFTClaimed(msg.sender,_idIDO,quantityNFT,block.timestamp);
    }
    function calculatorReceiveNFT(uint32 _idIDO, address _investor) public view returns(uint256) {
        uint128 amountTotalRaised = idoContract.getTotalAmountRaisedListIDO(_idIDO);
        uint16 pricePerUnit = idoContract.getPricePerUnitIDO(_idIDO);
        uint256 amountInvestor = idoContract.getAmountUserIDO(_idIDO, _investor);
        uint256 totalSupply = amountTotalRaised / pricePerUnit;
        uint256 receiveNFT = ((amountInvestor * totalSupply) / amountTotalRaised) / 1 ether;
        return receiveNFT;
    }
    function callGetAmountTotalRaised(uint32 _idIDO)public view returns(uint128 amountRaised){
        return idoContract.getTotalAmountRaisedListIDO(_idIDO);
    }

    function callGetAmountUserIDO(uint32 _idIDO,address _address)public view returns(uint256 amount){
        return idoContract.getAmountUserIDO(_idIDO, _address);
    }

    function callGetIsStatusIDO(uint32 _idIDO) public  view returns (IDOStatus) {
        return idoContract.getIsStatusIDO(_idIDO);
    }
    function callGetPricePerUnitIDO(uint32 _idIDO) external view returns(uint16){
        return idoContract.getPricePerUnitIDO(_idIDO);
    }


}