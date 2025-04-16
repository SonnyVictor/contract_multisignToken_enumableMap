// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DateTime.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LockAIINCENTIVES is Ownable {
    IERC20 public token;
    DateTime private dateTimeContract;
    uint256 public constant totalAmount = 15_000_000 * 10 ** 18;
    uint256 public constant UnLockEachMonth = 281_250 * 10 ** 18;
    uint256 private TGE = 1_500_000 ether;
    struct PrivateSaler {
        uint256 withdrawTimeUser;
        uint256 amount;
        bool isWithdraw;
    }
    address public  addressClaim;
    mapping(uint256 => PrivateSaler) private withdrawTime;
    mapping(address => bool) private isTGE;

    event WithdrawToken(address addressWithdraw, uint256 amount, uint256 time);
    event WithdrawTokenEachMonth(
        uint256 id,
        address addressWithdraw,
        uint256 amount,
        uint256 time
    );

    constructor(
        IERC20 _token,
        address _addressDateTime,
        address _owner
    ) Ownable(msg.sender) {
        token = IERC20(_token);
        dateTimeContract = DateTime(_addressDateTime);
        initWithdrawTime(2025, 6, 30, 48);
        transferOwnership(_owner);
    }

    function setToken(IERC20 _token) external onlyOwner{
        token = _token;
    }
    function setAddressClaim(address _address) public onlyOwner{
        addressClaim = _address;
    }

    function initWithdrawTime(
        uint16 _years,
        uint8 _month,
        uint8 _day,
        uint8 _numberMonths
    ) private {
        uint16[] memory yearsss = new uint16[](_numberMonths);
        uint8[] memory months = new uint8[](_numberMonths);
        yearsss[0] = _years;
        months[0] = _month;

        for (uint8 i = 1; i < _numberMonths; i++) {
            yearsss[i] = yearsss[i - 1];
            months[i] = months[i - 1] + 1;
            if (months[i] > 12) {
                yearsss[i]++;
                months[i] = 1;
            }
        }

        for (uint8 i = 0; i < _numberMonths; i++) {
            withdrawTime[i] = PrivateSaler(
                useDateTime(yearsss[i], months[i], _day),
                UnLockEachMonth,
                false
            );
        }
    }

    function getContractHoldToken() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function unClockTGE() external {
        require(
            token.balanceOf(address(this)) >= 0,
            "Insufficient account balance"
        );   
        require(addressClaim == msg.sender || msg.sender == owner(), "Incorrect address");
        require(isTGE[msg.sender]==true,"Already TGE");
        PrivateSaler storage infor = withdrawTime[0];
        require(block.timestamp > infor.withdrawTimeUser,"It's not time yet");
        isTGE[msg.sender]=true;
        SafeERC20.safeTransfer(token, _msgSender(), TGE);
    }


    function unclockTokenMonthly() external {
        require(
            token.balanceOf(address(this)) >= 0,
            "Insufficient account balance"
        );
        require(addressClaim == msg.sender || msg.sender == owner(), "Incorrect address");
        for (uint8 i = 0; i <= 10; i++) {
            PrivateSaler storage infor = withdrawTime[i];
            if (
                !infor.isWithdraw && block.timestamp >= infor.withdrawTimeUser
            ) {
                infor.isWithdraw = true;
                SafeERC20.safeTransfer(token, msg.sender, infor.amount);
                emit WithdrawTokenEachMonth(
                    i,
                    msg.sender,
                    infor.amount,
                    block.timestamp
                );
            }
        }
    }

    function withdraw() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        SafeERC20.safeTransfer(token, _msgSender(), balance);
    }

    function useDateTime(
        uint16 year,
        uint8 month,
        uint8 day
    ) public view returns (uint256) {
        uint256 timestamp = dateTimeContract.toTimestamp(year, month, day);
        return timestamp;
    }

    function getWithdrawTime(
        uint256 index
    ) public view returns (uint256, uint256, bool) {
        PrivateSaler storage sale = withdrawTime[index];
        return (sale.withdrawTimeUser, sale.amount, sale.isWithdraw);
    }
}