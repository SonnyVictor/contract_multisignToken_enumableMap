/**
 *Submitted for verification at snowscan.xyz on 2025-04-09
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/utils/Address.sol";
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        return msg.data;
    }
}

contract ERC20 is Context, IERC20 {
    using Address for address;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowance(sender, _msgSender()) - amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, allowance(_msgSender(), spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, allowance(_msgSender(), spender) - subtractedValue);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + amount;
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply + amount;
        _balances[account] = _balances[account] + amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account] - amount;
        _totalSupply = _totalSupply - amount;
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract ABCStaking is Ownable, ReentrancyGuard, ERC20("ABC Staking Pool", "ABC-ABC") {
    address public TOKEN_CASTLE_FACTORY;

    bool public hasUserLimit;
    bool public hasPoolLimit;
    bool public isInitialized;

    mapping(IERC20 => uint256) public accTokenPerShare;
    uint256 public stakingBlock;
    uint256 public stakingEndBlock;
    uint256 public unStakingBlock;
    uint256 public unStakingFee;
    uint256 public feePeriod;
    address public feeCollector;
    uint256 public bonusEndBlock;
    uint256 public startBlock;
    uint256 public lastRewardBlock;
    uint256 public poolLimitPerUser;
    uint256 public poolCap;
    uint256 public totalStaked;

    mapping(IERC20 => uint256) public rewardPerBlock;
    mapping(IERC20 => uint256) public PRECISION_FACTOR;
    IERC20[] public rewardTokens;
    IERC20 public stakedToken;

    mapping(address => UserInfo) public userInfo;

    struct UserInfo {
        uint256 amount;
        uint256 lastStakingBlock;
        mapping(IERC20 => uint256) rewardDebt;
    }

    bool public poolStakingStatus;

    struct UserStake {
        address addr;
        uint256 amount;
        uint256 startStakeBlock;
        uint256 endStakeBlock;
    }
    mapping(address => UserStake[]) public stakeDetails;
    uint256 public lockingDuration;

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event NewStartAndEndBlocks(uint256 startBlock, uint256 endBlock);
    event NewRewardPerBlock(uint256 rewardPerBlock, IERC20 token,uint256 indexToken);
    event NewPoolLimit(uint256 poolLimitPerUser);
    event NewPoolCap(uint256 poolCap);
    event RewardsStop(uint256 blockNumber);
    event Withdraw(address indexed user, uint256 amount);
    event NewRewardToken(IERC20 token, uint256 rewardPerBlock, uint256 p_factor);
    event RemoveRewardToken(IERC20 token);
    event NewStakingBlocks(uint256 startStakingBlock, uint256 endStakingBlock);
    event NewUnStakingBlock(uint256 startUnStakingBlock);

    constructor() {
        TOKEN_CASTLE_FACTORY = msg.sender;
        poolStakingStatus = true;

    }

    function initialize(
        IERC20 _stakedToken,
        IERC20[] memory _rewardTokens,
        uint256[] memory _rewardPerBlock,
        uint256[] memory _startEndBlocks,
        uint256[] memory _stakingBlocks,
        uint256 _unStakingBlock,
        uint256[] memory _feeSettings,
        address _feeCollector,
        uint256 _poolLimitPerUser,
        uint256 _poolCap,
        address _admin
    ) external {
        require(!isInitialized && msg.sender == TOKEN_CASTLE_FACTORY, "Init failed");
        require(_rewardTokens.length == _rewardPerBlock.length, "Mismatch length");
        require(address(_stakedToken) != address(0) && address(_feeCollector) != address(0) && address(_admin) != address(0), "Invalid address");
        require(_stakingBlocks[0] < _stakingBlocks[1], "Invalid staking blocks");

        isInitialized = true;
        stakedToken = _stakedToken;
        rewardTokens = _rewardTokens;
        startBlock = _startEndBlocks[0];
        bonusEndBlock = _startEndBlocks[1];
        stakingBlock = _stakingBlocks[0];
        stakingEndBlock = _stakingBlocks[1];
        unStakingBlock = _unStakingBlock;
        unStakingFee = _feeSettings[0];
        feePeriod = _feeSettings[1];
        feeCollector = _feeCollector;
        lastRewardBlock = startBlock;
        totalStaked = 0;

        if (_poolLimitPerUser > 0) {
            hasUserLimit = true;
            poolLimitPerUser = _poolLimitPerUser;
        }
        if (_poolCap > 0) {
            hasPoolLimit = true;
            poolCap = _poolCap;
        }

        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            uint256 decimals = uint256(_rewardTokens[i].decimals());
            require(decimals < 30, "Invalid decimals");
            PRECISION_FACTOR[_rewardTokens[i]] = 10 ** (30 - decimals);
            rewardPerBlock[_rewardTokens[i]] = _rewardPerBlock[i];
        }

        transferOwnership(_admin);
    }

    function setPoolStatus(bool _newPoolStatus) external onlyOwner {
        poolStakingStatus = _newPoolStatus;
    }

    function setLockingDuration(uint256 _numbBlocks) external onlyOwner {
        lockingDuration = _numbBlocks;
    }

    function enterStakeUser(uint256 _amount) internal returns (bool success) {
        UserStake memory currentStake;
        currentStake.addr = msg.sender;
        currentStake.amount = _amount;
        currentStake.startStakeBlock = block.number;
        currentStake.endStakeBlock = block.number + lockingDuration;
        stakeDetails[msg.sender].push(currentStake);
        return true;
    }

    function getUserStakedCount(address _user) public view returns (uint256) {
        return stakeDetails[_user].length;
    }

    function getStakedSchedule(address _user) public view returns (uint256[] memory, uint256[] memory, uint256[] memory) {
        uint256 stakedCount = stakeDetails[_user].length;
        uint256[] memory startStake = new uint256[](stakedCount);
        uint256[] memory endStake = new uint256[](stakedCount);
        uint256[] memory amount = new uint256[](stakedCount);

        for (uint256 i = 0; i < stakedCount; i++) {
            startStake[i] = stakeDetails[_user][i].startStakeBlock;
            endStake[i] = stakeDetails[_user][i].endStakeBlock;
            amount[i] = stakeDetails[_user][i].amount;
        }
        return (startStake, endStake, amount);
    }

    function getUnstakeAmount(address _user) public view returns (uint256) {
        uint256 claimAmount;
        for (uint256 i = 0; i < stakeDetails[_user].length; i++) {
            if (stakeDetails[_user][i].endStakeBlock < block.number) {
                claimAmount += stakeDetails[_user][i].amount;
            }
        }
        return claimAmount;
    }

    function leaveStakeUser() internal returns (uint256) {
        require(msg.sender != address(0), "Invalid address");
        UserInfo storage user = userInfo[msg.sender];
        uint256 claimAmount = 0;
        uint256[] memory indicesToRemove = new uint256[](
            stakeDetails[msg.sender].length
        );
        uint256 removeCount = 0;

        for (uint256 i = 0; i < stakeDetails[msg.sender].length; i++) {
            if (
                stakeDetails[msg.sender][i].endStakeBlock < block.number ||
                bonusEndBlock < block.number
            ) {
                claimAmount += stakeDetails[msg.sender][i].amount;
                indicesToRemove[removeCount] = i;
                removeCount++;
            }
        }

        require(user.amount >= claimAmount, "Insufficient staked amount");

        for (uint256 i = removeCount; i > 0; i--) {
            uint256 index = indicesToRemove[i - 1];
            if (index < stakeDetails[msg.sender].length - 1) {
                stakeDetails[msg.sender][index] = stakeDetails[msg.sender][
                    stakeDetails[msg.sender].length - 1
                ];
            }
            stakeDetails[msg.sender].pop();
        }

        return claimAmount;
    }

    function deposit(uint256 _amount) external nonReentrant {
        require(poolStakingStatus, "Pool is not ready");
        require(stakingBlock <= block.number, "Staking has not started");
        require(stakingEndBlock >= block.number, "Staking has ended");
        require(enterStakeUser(_amount), "Stake failed");

        UserInfo storage user = userInfo[msg.sender];
        if (hasPoolLimit) {
            require(_amount + totalStaked <= poolCap, "Pool cap reached");
        }
        if (hasUserLimit) {
            require(_amount + user.amount <= poolLimitPerUser, "User amount above limit");
        }

        _updatePool();
        _distributePendingRewards(user);

        if (_amount > 0) {
            user.amount = user.amount + _amount;
            totalStaked += _amount;
            stakedToken.transferFrom(msg.sender, address(this), _amount);
            _mint(msg.sender, _amount);
        }

        _updateUserDebt(user);
        user.lastStakingBlock = block.number;
        emit Deposit(msg.sender, _amount);
    }

    function _distributePendingRewards(UserInfo storage user) private {
        if (user.amount > 0) {
            for (uint256 i = 0; i < rewardTokens.length; i++) {
                IERC20 token = rewardTokens[i];
                uint256 pending = (user.amount * accTokenPerShare[token] / PRECISION_FACTOR[token]) - user.rewardDebt[token];
                if (pending > 0) {
                    uint256 balance = token.balanceOf(address(this));
                    require(balance >= pending, "Insufficient token balance");
                    safeERC20Transfer(token, msg.sender, pending);
                }
            }
        }
    }

    function _updateUserDebt(UserInfo storage user) private {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20 token = rewardTokens[i];
            user.rewardDebt[token] = user.amount * accTokenPerShare[token] / PRECISION_FACTOR[token];
        }
    }

    function safeERC20Transfer(IERC20 erc20, address _to, uint256 _amount) private {
        uint256 balance = erc20.balanceOf(address(this));
        if (_amount > balance) {
            erc20.transfer(_to, balance);
        } else {
            erc20.transfer(_to, _amount);
        }
    }

    function withdraw(bool isHarvest) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 _amount = isHarvest ? 0 : leaveStakeUser();
        require(!isHarvest && _amount > 0 ? user.amount >= _amount : true, "Invalid amount");

        _updatePool();
        _distributePendingRewards(user);

        if (_amount > 0) {
            user.amount = user.amount - _amount;
            totalStaked -= _amount;
            _burn(msg.sender, _amount);
            _amount = collectFee(_amount);
            stakedToken.transfer(msg.sender, _amount);
        }

        _updateUserDebt(user);
        emit Withdraw(msg.sender, _amount);
    }

    function collectFee(uint256 _amount) internal returns (uint256) {
        UserInfo storage user = userInfo[msg.sender];
        uint256 blockPassed = block.number - user.lastStakingBlock;
        if (feePeriod == 0) return _amount;
        if (feePeriod >= blockPassed) {
            uint256 collectedAmt = _amount * unStakingFee / 10000;
            stakedToken.transfer(feeCollector, collectedAmt);
            return _amount - collectedAmt;
        }
        return _amount;
    }

    function emergencyRewardWithdraw(uint256 _amount) external onlyOwner {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            rewardTokens[i].transfer(msg.sender, _amount);
        }
    }

    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(_tokenAddress != address(stakedToken), "Cannot be staked token");
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            require(_tokenAddress != address(rewardTokens[i]), "Cannot be reward token");
        }
        IERC20(_tokenAddress).transfer(msg.sender, _tokenAmount);
        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    function emergencyRemoval(uint256 _amount) external onlyOwner {
        require(stakedToken.balanceOf(address(this)) >= _amount, "Amount exceeds pool balance");
        if (_amount > 0) {
            stakedToken.transfer(msg.sender, _amount);
        }
    }

    function stopReward() external onlyOwner {
        bonusEndBlock = block.number;
    }

    function updateFeePeriod(uint256 _newFeePeriod) external onlyOwner {
        feePeriod = _newFeePeriod;
    }

    function updateUnstakingFee(uint256 _newFee) external onlyOwner {
        unStakingFee = _newFee;
    }

    function updateFeeCollector(address _newCollector) external onlyOwner {
        require(_newCollector != feeCollector, "Already the fee collector");
        feeCollector = _newCollector;
    }

    function updatePoolLimitPerUser(bool _hasUserLimit, uint256 _poolLimitPerUser) external onlyOwner {
        require(hasUserLimit, "Must be set");
        if (_hasUserLimit) {
            poolLimitPerUser = _poolLimitPerUser;
        } else {
            hasUserLimit = _hasUserLimit;
            poolLimitPerUser = 0;
        }
        emit NewPoolLimit(poolLimitPerUser);
    }

    function updatePoolCap(bool _hasPoolLimit, uint256 _poolCap) external onlyOwner {
        require(hasPoolLimit, "Must be set");
        if (_hasPoolLimit) {
            poolCap = _poolCap;
        } else {
            hasPoolLimit = _hasPoolLimit;
            poolCap = 0;
        }
        emit NewPoolCap(poolCap);
    }

    function updateRewardPerBlock(uint256 _rewardPerBlock, IERC20 _token) external onlyOwner {
        (bool foundToken, uint256 tokenIndex) = findElementPosition(_token, rewardTokens);
        require(foundToken, "Cannot find token");
        rewardPerBlock[_token] = _rewardPerBlock;
        emit NewRewardPerBlock(_rewardPerBlock, _token, tokenIndex);
    }

    function updateStartAndEndBlocks(uint256 _startBlock, uint256 _bonusEndBlock) external onlyOwner {
        require(block.number < startBlock, "Pool has started");
        require(_startBlock < _bonusEndBlock, "New startBlock must be lower than new endBlock");
        require(block.number < _startBlock, "New startBlock must be higher than current block");
        require(stakingBlock <= _startBlock, "Staking block exceeds start block");
        require(stakingEndBlock <= _bonusEndBlock, "End staking block exceeds bonus end block");

        startBlock = _startBlock;
        bonusEndBlock = _bonusEndBlock;
        lastRewardBlock = startBlock;
        emit NewStartAndEndBlocks(_startBlock, _bonusEndBlock);
    }

    function updateStakingBlocks(uint256 _startStakingBlock, uint256 _endStakingBlock) external onlyOwner {
        require(_startStakingBlock <= startBlock, "Staking block exceeds start block");
        require(_startStakingBlock <= unStakingBlock, "Staking block exceeds unstaking block");
        require(block.number < _startStakingBlock, "New stakingBlock must be higher than current block");
        require(_startStakingBlock < _endStakingBlock, "Staking block exceeds end staking block");
        require(_endStakingBlock <= bonusEndBlock, "End staking block exceeds bonus end block");

        stakingBlock = _startStakingBlock;
        stakingEndBlock = _endStakingBlock;
        emit NewStakingBlocks(_startStakingBlock, _endStakingBlock);
    }

    function updateUnStakingBlock(uint256 _startUnStakingBlock) external onlyOwner {
        require(block.number < unStakingBlock, "Unstaking has started");
        require(stakingBlock <= _startUnStakingBlock, "Staking block exceeds unstaking block");
        require(block.number < _startUnStakingBlock, "New UnStakingBlock must be higher than current block");

        unStakingBlock = _startUnStakingBlock;
        emit NewUnStakingBlock(_startUnStakingBlock);
    }

    function pendingReward(address _user) external view returns (uint256[] memory, IERC20[] memory) {
        UserInfo storage user = userInfo[_user];
        uint256 stakedTokenSupply = totalStaked;
        uint256[] memory userPendingRewards = new uint256[](rewardTokens.length);
        if (block.number > lastRewardBlock && stakedTokenSupply != 0) {
            uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
            for (uint256 i = 0; i < rewardTokens.length; i++) {
                uint256 tokenReward = multiplier * rewardPerBlock[rewardTokens[i]];
                uint256 adjustedTokenPerShare = accTokenPerShare[rewardTokens[i]] + (tokenReward * PRECISION_FACTOR[rewardTokens[i]] / stakedTokenSupply);
                userPendingRewards[i] = (user.amount * adjustedTokenPerShare / PRECISION_FACTOR[rewardTokens[i]]) - user.rewardDebt[rewardTokens[i]];
            }
            return (userPendingRewards, rewardTokens);
        } else {
            for (uint256 i = 0; i < rewardTokens.length; i++) {
                userPendingRewards[i] = (user.amount * accTokenPerShare[rewardTokens[i]] / PRECISION_FACTOR[rewardTokens[i]]) - user.rewardDebt[rewardTokens[i]];
            }
            return (userPendingRewards, rewardTokens);
        }
    }

    function pendingRewardByToken(address _user, IERC20 _token) external view returns (uint256) {
        (bool foundToken, ) = findElementPosition(_token, rewardTokens);
        if (!foundToken) {
            return 0;
        }
        UserInfo storage user = userInfo[_user];
        uint256 stakedTokenSupply = totalStaked;
        if (block.number > lastRewardBlock && stakedTokenSupply != 0) {
            uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
            uint256 tokenReward = multiplier * rewardPerBlock[_token];
            uint256 adjustedTokenPerShare = accTokenPerShare[_token] + (tokenReward * PRECISION_FACTOR[_token] / stakedTokenSupply);
            return (user.amount * adjustedTokenPerShare / PRECISION_FACTOR[_token]) - user.rewardDebt[_token];
        } else {
            return (user.amount * accTokenPerShare[_token] / PRECISION_FACTOR[_token]) - user.rewardDebt[_token];
        }
    }

    function _updatePool() internal {
        if (block.number <= lastRewardBlock) {
            return;
        }
        uint256 stakedTokenSupply = totalStaked;
        if (stakedTokenSupply == 0) {
            lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20 token = rewardTokens[i];
            uint256 tokenReward = multiplier * rewardPerBlock[token];
            uint256 precisionAdjustment = tokenReward * PRECISION_FACTOR[token];
            uint256 increment = precisionAdjustment / stakedTokenSupply;
            accTokenPerShare[token] = accTokenPerShare[token] + increment;
        }
        lastRewardBlock = block.number;
    }

    function _getMultiplier(uint256 _from, uint256 _to) internal view returns (uint256) {
        if (_to <= bonusEndBlock) {
            return _to - _from;
        } else if (_from >= bonusEndBlock) {
            return 0;
        } else {
            return bonusEndBlock - _from;
        }
    }

    function addRewardToken(IERC20 _token, uint256 _rewardPerBlock) external onlyOwner {
        require(address(_token) != address(0) && address(_token) != address(this), "Must be a real token");
        (bool foundToken, ) = findElementPosition(_token, rewardTokens);
        require(!foundToken, "Token exists");
        rewardTokens.push(_token);

        uint256 decimalsRewardToken = _token.decimals();
        require(decimalsRewardToken < 30, "Must be inferior to 30");
        PRECISION_FACTOR[_token] = 10 ** (30 - decimalsRewardToken);
        rewardPerBlock[_token] = _rewardPerBlock;
        accTokenPerShare[_token] = 0;

        emit NewRewardToken(_token, _rewardPerBlock, PRECISION_FACTOR[_token]);
    }

    function removeRewardToken(IERC20 _token) external onlyOwner {
        require(address(_token) != address(0) && address(_token) != address(this), "Must be a real token");
        require(rewardTokens.length > 0, "List of token is empty");

        (bool foundToken, uint256 tokenIndex) = findElementPosition(_token, rewardTokens);
        require(foundToken, "Cannot find token");
        (bool success, IERC20[] memory newRewards) = removeElement(tokenIndex, rewardTokens);
        rewardTokens = newRewards;
        require(success, "Remove token unsuccessfully");
        PRECISION_FACTOR[_token] = 0;
        rewardPerBlock[_token] = 0;
        accTokenPerShare[_token] = 0;

        emit RemoveRewardToken(_token);
    }

    function removeElement(uint256 _index, IERC20[] storage _array) internal returns (bool, IERC20[] memory) {
        if (_index >= _array.length) {
            return (false, _array);
        }
        for (uint256 i = _index; i < _array.length - 1; i++) {
            _array[i] = _array[i + 1];
        }
        _array.pop();
        return (true, _array);
    }

    function findElementPosition(IERC20 _token, IERC20[] storage _array) internal view returns (bool, uint256) {
        for (uint256 i = 0; i < _array.length; i++) {
            if (_array[i] == _token) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    function getUserDebt(address _usr) external view returns (IERC20[] memory, uint256[] memory) {
        uint256[] memory userDebt = new uint256[](rewardTokens.length);
        UserInfo storage user = userInfo[_usr];
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            userDebt[i] = user.rewardDebt[rewardTokens[i]];
        }
        return (rewardTokens, userDebt);
    }

    function getUserDebtByToken(address _usr, IERC20 _token) external view returns (uint256) {
        UserInfo storage user = userInfo[_usr];
        return user.rewardDebt[_token];
    }

    function getAllRewardPerBlock(IERC20[] memory _tokens) external view returns (uint256[] memory) {
        uint256[] memory RPBlist = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            RPBlist[i] = rewardPerBlock[_tokens[i]];
        }
        return RPBlist;
    }

    function getAllAccTokenPerShared(IERC20[] memory _tokens) external view returns (uint256[] memory) {
        uint256[] memory ATPSlist = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            ATPSlist[i] = accTokenPerShare[_tokens[i]];
        }
        return ATPSlist;
    }

    function getAllPreFactor(IERC20[] memory _tokens) external view returns (uint256[] memory) {
        uint256[] memory PFlist = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            PFlist[i] = PRECISION_FACTOR[_tokens[i]];
        }
        return PFlist;
    }

    function getStakingEndBlock() external view returns (uint256) {
        return stakingEndBlock;
    }

    function getUnStakingFee() external view returns (uint256) {
        return unStakingFee;
    }

    function getFeePeriod() external view returns (uint256) {
        return feePeriod;
    }

    function getFeeCollector() external view returns (address) {
        return feeCollector;
    }

    function getLastStakingBlock(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        return user.lastStakingBlock;
    }
}

