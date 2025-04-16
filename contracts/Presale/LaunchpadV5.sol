// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LaunchpadV5 is Pausable, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _supportedPaymentTokens;

    // Event
    event CreateIDO(
        uint256 indexed projectId,
        address indexed projectOwner,
        address indexed token,
        uint256 minInvestment,
        uint256 maxInvestment,
        uint256 pricePerUnit,
        uint256 endTimeInMinutes
    );
    event InvestmentMade(
        uint256 indexed projectId,
        address indexed investor,
        uint256 amountInvested
    );

    event AddPaymentToken(address paytoken);
    event RemovePaymentToken(address paytoken);

    constructor() Ownable(msg.sender) {
        launchPadadmin = msg.sender;
    }

    struct IDOProject {
        address projectOwner;
        IERC20 token;
        uint256 minInvestment;
        uint256 maxInvestment;
        uint256 pricePerUnit;
        uint256 IDOduration;
        bool isActive;
        uint256 totalAmountRaised;
        uint256 totalNFTIDOClaimed;
        address[] whiteListedAddresses;
        address[] projectInvestors;
        bool withdrawn;
    }
    //address => token
    mapping(uint256 => mapping(address => uint256)) public projectInvestments;
    //
    mapping(uint256 => mapping(address => uint256)) public allocation;
    mapping(uint256 => mapping(address => bool)) public whitelistedAddresses;

    // mapping

    function AddUsersForAParticularProject(
        uint256 _projectId,
        address[] calldata _users
    ) external whenNotPaused {
        if (_projectId > projectsCurrentId || _projectId == 0)
            revert InvalidProjectID();
        IDOProject storage project = projects[_projectId];
        if (msg.sender != project.projectOwner) revert NotProjectOwner();
        for (uint256 i = 0; i < _users.length; i++) {
            address user = _users[i];
            if (user == address(0)) revert AddressZero();
            if (whitelistedAddresses[_projectId][user])
                revert UserAlreadyWhitelisted();
            whitelistedAddresses[_projectId][user] = true;
            project.whiteListedAddresses.push(user);
        }
    }

    function RemoveUsersForAParticularProject(
        uint256 _projectId,
        address[] calldata _users
    ) external whenNotPaused {
        if (_projectId > projectsCurrentId || _projectId == 0)
            revert InvalidProjectID();

        IDOProject storage project = projects[_projectId];
        if (msg.sender != project.projectOwner) revert NotProjectOwner();

        for (uint256 i = 0; i < _users.length; i++) {
            address user = _users[i];
            whitelistedAddresses[_projectId][user] = false;
            for (uint256 j = 0; j < project.whiteListedAddresses.length; j++) {
                if (project.whiteListedAddresses[j] == user) {
                    project.whiteListedAddresses[j] = project
                        .whiteListedAddresses[
                            project.whiteListedAddresses.length - 1
                        ];
                    project.whiteListedAddresses.pop();
                    break;
                }
            }
        }
    }

    function withdrawAmountRaised(
        uint256 _projectID
    ) external payable whenNotPaused nonReentrant {
        if (_projectID > projectsCurrentId || _projectID == 0)
            revert InvalidProjectID();
        IDOProject storage project = projects[_projectID];

        if (msg.sender != project.projectOwner) revert NotProjectOwner();
        if (project.withdrawn == true) revert AlreadyWithdrawn();

        if (block.timestamp < project.IDOduration)
            revert ProjectStillInProgress();
        uint256 amountRaised = project.totalAmountRaised;

        // project.totalAmountRaised = 0;
        project.withdrawn = true;
        (bool success, ) = payable(msg.sender).call{value: amountRaised}("");
        if (!success) revert TxnFailed();
    }

    mapping(uint256 => IDOProject) public projects;

    /////////////////STATE VARIABLES///////////////////

    address public launchPadadmin;

    uint256 projectsCurrentId;

    //ERROR
    error NotLaunchPadAdmin();
    error TokenPriceMustBeGreaterThanZero();
    error MinInvestmentMustBeDivisible5GreaterOrThanZero();
    error MaxInvestmentMustBeDivisible5OrGreaterOrEqualToMinInvestment();
    error MinimumInvestmentMustBeGreaterThanZero();
    error MaxInvestmentMustBeGreaterOrEqualToMinInvestment();
    error MaxCapMustBeGreaterOrEqualToMaxInvestment();
    error EndTimeMustBeInFuture();
    error InvalidProjectID();
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

    function createIDO(
        IERC20 _token,
        uint256 _minInvestment,
        uint256 _maxInvestment,
        uint256 _pricePerUnit,
        uint256 _endTime,
        address[] memory _whiteListedUsers
    ) external onlySupportedPaymentToken(_token) whenNotPaused returns (bool) {
        // if (_tokenPrice == 0) revert TokenPriceMustBeGreaterThanZero();
        if (
            _minInvestment % 5 != 0 ||
            _minInvestment > _maxInvestment ||
            _minInvestment == 0
        ) revert MinimumInvestmentMustBeGreaterThanZero();
        if (
            _maxInvestment % 5 != 0 ||
            _maxInvestment < _minInvestment ||
            _maxInvestment == 0
        ) revert MaxInvestmentMustBeGreaterOrEqualToMinInvestment();
        if (_whiteListedUsers.length == 0) revert EmptyAddress();

        projectsCurrentId = projectsCurrentId + 1;

        for (uint256 i; i < _whiteListedUsers.length; i++) {
            address user = _whiteListedUsers[i];
            if (user == address(0)) revert AddressZero();
            whitelistedAddresses[projectsCurrentId][user] = true;
        }

        IDOProject storage project = projects[projectsCurrentId];

        project.projectOwner = msg.sender;
        project.token = _token;
        project.minInvestment = _minInvestment;
        project.maxInvestment = _maxInvestment;
        project.pricePerUnit = _pricePerUnit;
        project.IDOduration = (_endTime * 1 minutes).add(block.timestamp);
        project.whiteListedAddresses = _whiteListedUsers;
        project.isActive = true;

        emit CreateIDO(
            projectsCurrentId,
            msg.sender,
            address(_token),
            _minInvestment,
            _maxInvestment,
            _pricePerUnit,
            _endTime
        );
        return true;
    }

    function getIDOTokenBalanceInLaunchPad(
        uint256 projectId
    ) public view returns (uint256) {
        if (projectId > projectsCurrentId || projectId == 0)
            revert InvalidProjectID();
        IDOProject memory project = projects[projectId];
        return IERC20(project.token).balanceOf(address(this));
    }

    function cancelIDOProject(uint256 _projectId) external {
        if (_projectId > projectsCurrentId || _projectId == 0)
            revert InvalidProjectID();
        require(projectInvestments[_projectId][msg.sender] > 0, "You not join");
        IDOProject storage project = projects[_projectId];
        // project.isActive = false;
        // project.IDOduration = 0;
        projectInvestments[_projectId][msg.sender] = 0;

        IERC20(project.token).safeTransfer(
            msg.sender,
            projectInvestments[_projectId][msg.sender]
        );
    }

    function isWhitelisted(
        uint256 _projectId,
        address _address
    ) public view returns (bool) {
        return whitelistedAddresses[_projectId][_address];
    }

    function invest(
        uint256 _projectId,
        uint256 _amountToken
    ) external whenNotPaused {
        if (_projectId > projectsCurrentId || _projectId == 0)
            revert InvalidProjectID();
        IDOProject storage project = projects[_projectId];
        if (isWhitelisted(_projectId, msg.sender) == false)
            revert NotWhiteListed();
        if (project.isActive == false) revert ProjectNotActive();
        if (block.timestamp > project.IDOduration) revert ProjectEnded();
        if (_amountToken < project.minInvestment)
            revert InvestmentAmtBelowMinimum();
        if (
            (projectInvestments[_projectId][msg.sender].add(_amountToken)) >
            project.maxInvestment
        ) revert InvestmentAmtExceedsMaximum();
        if (_amountToken % project.pricePerUnit != 0) {
            revert NotDivisiblePriceUnit();
        }
        uint256 investmentAmount = _amountToken;
        projectInvestments[_projectId][msg.sender] = projectInvestments[
            _projectId
        ][msg.sender].add(investmentAmount);
        project.projectInvestors.push(msg.sender);

        IERC20(project.token).safeTransferFrom(
            _msgSender(),
            address(this),
            _amountToken
        );
        project.totalAmountRaised = project.totalAmountRaised.add(
            investmentAmount
        );
        emit InvestmentMade(
            _projectId,
            msg.sender,
            projectInvestments[_projectId][msg.sender]
        );
    }

    /// Views
    function getAllInfoListIDO(
        uint256 _idIDO
    ) external view returns (IDOProject memory) {
        if (_idIDO > projectsCurrentId || _idIDO == 0)
            revert InvalidProjectID();
        IDOProject memory project = projects[_idIDO];
        return project;
    }

    function getAddressKolsIDO(
        uint256 _idIDO
    ) external view returns (address KOLs) {
        if (_idIDO > projectsCurrentId || _idIDO == 0)
            revert InvalidProjectID();
        IDOProject memory project = projects[_idIDO];
        return project.projectOwner;
    }

    function getAddressInvestor(
        uint256 _idIDO
    ) public view returns (address[] memory) {
        if (_idIDO > projectsCurrentId || _idIDO == 0)
            revert InvalidProjectID();
        IDOProject memory project = projects[_idIDO];
        return project.projectInvestors;
    }

    function getAddressWhiteList(
        uint256 _idIDO
    ) public view returns (address[] memory) {
        if (_idIDO > projectsCurrentId || _idIDO == 0)
            revert InvalidProjectID();
        IDOProject memory project = projects[_idIDO];
        return project.whiteListedAddresses;
    }

    function getPaymentTokenListIDO(
        uint256 _idIDO
    ) external view returns (IERC20) {
        if (_idIDO > projectsCurrentId || _idIDO == 0)
            revert InvalidProjectID();
        IDOProject memory project = projects[_idIDO];
        return IERC20(project.token);
    }

    function getMinInvestmentListIDO(
        uint256 _idIDO
    ) external view returns (uint256) {
        if (_idIDO > projectsCurrentId || _idIDO == 0)
            revert InvalidProjectID();
        IDOProject memory project = projects[_idIDO];
        return project.minInvestment;
    }

    function getMaxInvestmentListIDO(
        uint256 _idIDO
    ) external view returns (uint256) {
        if (_idIDO > projectsCurrentId || _idIDO == 0)
            revert InvalidProjectID();
        IDOProject memory project = projects[_idIDO];
        return project.maxInvestment;
    }

    function getTimeEndIDO(uint256 _idIDO) external view returns (uint256) {
        if (_idIDO > projectsCurrentId || _idIDO == 0)
            revert InvalidProjectID();
        IDOProject memory project = projects[_idIDO];
        return project.IDOduration;
    }

    function getTotalAmountRaisedListIDO(
        uint256 _idIDO
    ) external view returns (uint256) {
        if (_idIDO > projectsCurrentId || _idIDO == 0)
            revert InvalidProjectID();
        IDOProject memory project = projects[_idIDO];
        return project.totalAmountRaised;
    }

    function getIsActivedListIDO(uint256 _idIDO) external view returns (bool) {
        if (_idIDO > projectsCurrentId || _idIDO == 0)
            revert InvalidProjectID();
        IDOProject memory project = projects[_idIDO];
        return project.isActive;
    }

    function getAmountInvestor(uint256 _idIDO) public view returns (uint256) {
        if (_idIDO > projectsCurrentId || _idIDO == 0)
            revert InvalidProjectID();
        IDOProject memory project = projects[_idIDO];
        return project.projectInvestors.length;
    }

    function getTotalInvestorsForAParticularProject(
        uint256 projectId
    ) external view returns (uint256) {
        if (projectId > projectsCurrentId || projectId == 0)
            revert InvalidProjectID();

        IDOProject memory project = projects[projectId];
        return project.projectInvestors.length;
    }

    // change admin launchpad
    function changeLaunchPadAdmin(address _newAdmin) external whenNotPaused {
        if (msg.sender != launchPadadmin) revert NotLaunchPadAdmin();
        if (_newAdmin == address(0)) revert AddressZero();
        if (_newAdmin == launchPadadmin) revert OldAdmin();
        launchPadadmin = _newAdmin;
    }

    // Payment Token
    function addPaymentToken(IERC20 paymentToken) external onlyOwner {
        require(
            _supportedPaymentTokens.add(address(paymentToken)),
            "YourContract: already supported"
        );
        emit AddPaymentToken(address(paymentToken));
    }

    function removePaymentToken(IERC20 paymentToken) external onlyOwner {
        _supportedPaymentTokens.remove(address(paymentToken));
        emit RemovePaymentToken(address(paymentToken));
    }

    function quantityPaymentToken() external view returns (uint256) {
        return _supportedPaymentTokens.length();
    }

    function valuePaymentToken() external view returns (address[] memory) {
        uint256 length = _supportedPaymentTokens.length();
        address[] memory tokens = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            tokens[i] = _supportedPaymentTokens.at(i);
        }
        return tokens;
    }

    function isPaymentTokenSupported(
        IERC20 paymentToken
    ) public view returns (bool) {
        return _supportedPaymentTokens.contains(address(paymentToken));
    }

    modifier onlySupportedPaymentToken(IERC20 paymentToken) {
        require(
            isPaymentTokenSupported(paymentToken),
            "YourContract: unsupported payment token"
        );
        _;
    }

    // WithDraw Token
    function withdrawToken(
        IERC20 _addressToken,
        uint256 _amount
    ) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");
        require(
            _addressToken.balanceOf(address(this)) >= _amount,
            "Insufficient balance in the contract"
        );
        _addressToken.safeTransfer(msg.sender, _amount);
    }

    function getTokenOnContract(
        IERC20 _addressToken
    ) external view returns (uint256) {
        uint256 balance = _addressToken.balanceOf(address(this));
        return balance;
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
