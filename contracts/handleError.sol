// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract IDOErrors {
    error NotLaunchPadAdmin();
    error TokenPriceMustBeGreaterThanZero();
    error MinInvestmentMustBeDivisible5GreaterOrThanZero();
    error MaxInvestmentMustBeDivisible5OrGreaterOrEqualToMinInvestment();    
    error MinimumInvestmentMustBeGreaterThanZero();
    error MaxInvestmentMustBeGreaterOrEqualToMinInvestment();
    error MaxCapMustBeGreaterOrEqualToMaxInvestment();
    error EndTimeMustBeInFuture();
    error InvalidIDOID();
    error ProjectNotActive();
    error InvestmentAmtBelowMinimum();
    error InvestmentAmtExceedsMaximum();
    error ProjectEnded();
    error NotProjectOwner();
    error AlreadyWithdrawn();
    error ProjectStillInProgress();
    error AddressZero();
    error TxnFailed();
    error TokenAlreadyWhitelisted();
    error ContractNotFullyFunded();
    error EmptyAddress();
    error NotWhiteListed();
    error MaxCapExceeded();
    error TokenAllocationMustBeGreaterThanZero();
    error UserAlreadyWhitelisted();
    error OldAdmin();
    error NotDivisiblePriceUnit();
    error Invalid_IDO_ID();
    error IDO_Not_Active();
    error IDO_Ended();
    error Not_IDO_Owner();
    error Not_Support_Token_This();
    error Not_Join_Or_Withdrawed();
    error IDO_isFished();
    error Id_IDO_Paused();
    error IDO_Has_Not_Started();
}