// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StakingEvents {
    event AdminTokenRecovery(address tokenRecovered, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event NewStartAndEndBlocks(uint256 startBlock, uint256 endBlock);
    event NewRewardPerBlock(uint256 rewardPerBlock, ERC20 token);
    event NewPoolLimit(uint256 poolLimitPerUser);
    event NewPoolCap(uint256 poolCap);
    event RewardsStop(uint256 blockNumber);
    event Withdraw(address indexed user, uint256 amount);
    event NewRewardToken(ERC20 token, uint256 rewardPerBlock, uint256 p_factor);
    event RemoveRewardToken(ERC20 token);
    event NewStakingBlocks(uint256 startStakingBlock, uint256 endStakingBlock);
    event NewUnStakingBlock(uint256 startUnStakingBlock);
}