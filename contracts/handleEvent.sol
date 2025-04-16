// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import "./InterfaceTest.sol";

contract IDOEvents {
    event CreateIDO(uint256 indexed idoId,address indexed idoOwner,address indexed token,uint256 minInvestment,uint256 maxInvestment,uint256 targetIDO,uint256 pricePerUnit,uint256 startTime,uint256 endTimeInMinutes);
    event InvestmentMade(uint256 indexed idoId,address indexed investor,uint256 amountInvested,uint256 timeInvestment);
    event CancelIDO(address addressCancelIDO,uint256 _id,uint256 timecancel,uint256 amountReceive);
    event AddPaymentToken(address paytoken);
    event RemovePaymentToken(address paytoken);
    event AddAddressWhiteList(uint256 idIDO,address[] user);
    event SetActiveIDO(uint32 idIDO,uint256 Time,IAARTMarket.IDOStatus Status);
}