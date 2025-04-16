// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakingToken is Ownable, ReentrancyGuard {
    constructor(IERC20 _stakingToken) Ownable(msg.sender) {
        poolstake[1] = PoolStake(
            1_000_000_000 ether,
            5_000_000_000_000 ether,
            7,
            4,
            0,
            0,
            false
        );
        poolstake[2] = PoolStake(
            1_000_000_000 ether,
            5_000_000_000_000 ether,
            14,
            10,
            0,
            0,
            false
        );
        poolstake[3] = PoolStake(
            1_000_000_000 ether,
            5_000_000_000_000 ether,
            30,
            20,
            0,
            0,
            false
        );
        poolstake[4] = PoolStake(
            1_000_000_000 ether,
            5_000_000_000_000 ether,
            45,
            30,
            0,
            0,
            false
        );
        stakingToken = _stakingToken;
    }

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IERC20 public immutable stakingToken;

    struct PoolStake {
        uint256 minStake;
        uint256 maxStake;
        uint256 lockDuration;
        uint256 interestRate;
        uint256 totalPoolStaked;
        uint256 totalUnstaked;
        bool isActive;
    }

    struct UserStakingInfo {
        uint256 startTimestamp;
        uint256 duration;
        uint256 endTimestamp;
        uint256 amountStake;
        uint256 totalReceive;
        bool staked;
        bool claimed;
    }

    mapping(uint256 => PoolStake) private poolstake;
    mapping(address => mapping(uint256 => UserStakingInfo)) private userStakes;

    event StakeToken(
        address userStaked,
        uint256 poolStake,
        uint256 timeStaked,
        uint256 endStaked,
        uint256 apy,
        uint256 amountStaked
    );
    event ClaimToken(
        address userStaked,
        uint256 poolStake,
        uint256 timeClaim,
        uint256 amountReceive
    );
    event UnStakeStakeToken(
        address userStaked,
        uint256 poolStake,
        uint256 timeUnStaked,
        uint256 amountReceive
    );

    // Write Function
    function stakeToken(uint256 _idPool, uint256 _amount) external {
        UserStakingInfo storage userStake_ = userStakes[msg.sender][_idPool];
        PoolStake storage idPool_ = poolstake[_idPool];
        require(
            userStake_.staked == false,
            "You staked in this pool, Stake in another pool"
        );
        require(idPool_.isActive == false, "Pool paused");
        require(
            _amount >= idPool_.minStake && _amount <= idPool_.maxStake,
            "Amount is below or above the minimum/maximum stake"
        );
        userStake_.startTimestamp = block.timestamp;
        userStake_.duration = idPool_.lockDuration * 1 days;
        userStake_.endTimestamp = block.timestamp + userStake_.duration;
        userStake_.amountStake = _amount;
        userStake_.totalReceive = calculateTotalStake(
            userStake_.amountStake,
            idPool_.interestRate
        );
        userStake_.staked = true;
        userStake_.claimed = false;
        idPool_.totalPoolStaked += _amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit StakeToken(
            msg.sender,
            _idPool,
            userStake_.startTimestamp,
            userStake_.endTimestamp,
            idPool_.interestRate,
            _amount
        );
    }

    function getTokenOnContract() external view returns (uint256) {
        uint256 contractBalance = stakingToken.balanceOf(address(this));
        return contractBalance;
    }

    function unStake(uint256 _idPool) external nonReentrant {
        UserStakingInfo storage userStake_ = userStakes[msg.sender][_idPool];
        PoolStake storage idPool_ = poolstake[_idPool];
        require(
            block.timestamp >= userStake_.endTimestamp,
            "It's not time to receive yet"
        );
        require(userStake_.staked == true, "You Already Staked Yet");
        uint256 reward = userStake_.totalReceive;
        idPool_.totalUnstaked += reward;
        uint256 contractBalance = stakingToken.balanceOf(address(this));
        require(
            contractBalance >= userStake_.totalReceive,
            "Contract doesn't have enough tokens"
        );
        resetUserStakingInfo(userStake_);
        stakingToken.safeTransfer(msg.sender, reward);
        emit ClaimToken(msg.sender, _idPool, block.timestamp, reward);
    }

    function resetUserStakingInfo(UserStakingInfo storage userStake_) internal {
        userStake_.startTimestamp = 0;
        userStake_.duration = 0;
        userStake_.endTimestamp = 0;
        userStake_.amountStake = 0;
        userStake_.totalReceive = 0;
        userStake_.staked = false;
        userStake_.claimed = false;
    }

    function setPoolStake(
        uint256 _idPool,
        uint256 _mixStake,
        uint256 _maxStake,
        uint256 _interestRate,
        bool _isActive
    ) external onlyOwner {
        PoolStake storage idPool_ = poolstake[_idPool];
        idPool_.minStake = _mixStake;
        idPool_.maxStake = _maxStake;
        idPool_.interestRate = _interestRate;
        idPool_.isActive = _isActive;
    }

    function withdrawToken(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");
        require(
            stakingToken.balanceOf(address(this)) >= _amount,
            "Insufficient balance in the contract"
        );
        stakingToken.safeTransfer(msg.sender, _amount);
    }

    function depositToken(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");
        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
    }

    function withdraw() external payable onlyOwner {
        uint256 _amount = address(this).balance;
        bool sent = payable(msg.sender).send(_amount);
        require(sent, "Failed to send Ether");
    }

    // Calculator
    function calculateTotalStake(
        uint256 _amountStake,
        uint256 _apy
    ) public pure returns (uint256) {
        uint256 dailyInterest = (_amountStake * _apy) / (100);
        return _amountStake + dailyInterest;
    }

    // Views
    function getPoolStake(
        uint256 _idPool
    ) external view returns (PoolStake memory) {
        return poolstake[_idPool];
    }

    function getUserStaked(
        address _userStaked,
        uint256 _idPool
    ) external view returns (UserStakingInfo memory) {
        return userStakes[_userStaked][_idPool];
    }

    function getToken() external view returns (IERC20 addressToken) {
        return stakingToken;
    }
}

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(
        uint256 a,
        uint256 b
    ) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}
