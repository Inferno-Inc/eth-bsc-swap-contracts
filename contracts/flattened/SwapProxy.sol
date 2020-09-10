
// File: @openzeppelin/contracts/GSN/Context.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// File: contracts/IBEP20.sol

pragma solidity 0.6.4;

interface IBEP20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the token name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view returns (address);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address _owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// File: contracts/SwapProxy.sol

pragma solidity 0.6.4;




contract SwapProxy is Context, Ownable {
    uint256 public swapFee;
    bool public status; // true for enabled; false for disabled;
    uint256 public tokenCount;

    struct TokenConfig {
        address contractAddr;
        uint256 lowerBound;
        uint256 upperBound;
        address relayer;
    }

    TokenConfig[] public tokens;
    mapping(address => uint256) public tokenIndexMap;

    event tokenTransfer(address indexed contractAddr, address indexed toAddr, uint256 indexed amount);
    event bnbTransfer(address indexed toAddr, uint256 indexed amount);
    event feeUpdate(uint256 fee);
    event statusUpdate(bool status);
    event tokenAdd(address indexed contractAddr, address indexed relayer, uint256 lowerBound, uint256 upperBound);
    event tokenRemove(address indexed contractAddr);

    constructor (uint256 fee) public {
        swapFee = fee;
        status = true;
    }

    function setStatus(bool statusToUpdate) public onlyOwner returns (bool) {
        status = statusToUpdate;
        emit statusUpdate(statusToUpdate);
        return true;
    }

    function updateSwapFee(uint256 fee) onlyOwner external returns (bool) {
        swapFee = fee;
        emit feeUpdate(fee);
        return true;
    }

    function addOrUpdateToken(address contractAddr, address relayer, uint256 lowerBound, uint256 upperBound) onlyOwner external returns (bool) {
        require(contractAddr != address(0x0), "contract address should not be empty");
        require(relayer != address(0x0), "relayer address should not be empty");

        TokenConfig memory tokenConfig = TokenConfig({
            contractAddr:    contractAddr,
            lowerBound:     lowerBound,
            upperBound:     upperBound,
            relayer:        relayer
        });

        uint256 index = tokenIndexMap[contractAddr];
        if (index == 0) {
            tokens.push(tokenConfig);
            tokenIndexMap[contractAddr] = tokens.length;
        } else {
            tokens[index - 1] = tokenConfig;
        }

        tokenCount = tokens.length;
        emit tokenAdd(contractAddr, relayer, lowerBound, upperBound);
        return true;
    }

    function removeToken(address contractAddr) onlyOwner external returns (bool) {
        require(contractAddr != address(0x0), "contract address should not be empty");

        uint256 index = tokenIndexMap[contractAddr];
        require(index > 0, "token does not exist");

        TokenConfig memory tokenConfig = tokens[index - 1];
        delete tokenIndexMap[tokenConfig.contractAddr];

        if (index != tokens.length) {
            tokens[index - 1] = tokens[tokens.length - 1];
            tokenIndexMap[tokens[index - 1].contractAddr] = index;
        }
        tokens.pop();
        tokenCount = tokens.length;

        emit tokenRemove(contractAddr);
        return true;
    }

    function transfer(address contractAddr, address to,  uint256 amount) onlyOwner external returns (bool) {
        require(amount > 0, "amount should be larger than 0");
        require(contractAddr != address(0x0), "contract address should not be empty");
        require(to != address(0x0), "relayer address should not be empty");

        bool success = IBEP20(contractAddr).transfer(to, amount);
        require(success, "transfer token failed");

        return true;
    }

    function swap(address contractAddr, uint256 amount) payable external returns (bool) {
        require(status, "swap proxy is disabled");
        require(msg.value >= swapFee, "received BNB amount should be equal to the amount of swapFee");
        require(amount > 0, "amount should be larger than 0");

        uint256 index = tokenIndexMap[contractAddr];
        require(index > 0, "token is not supported");

        TokenConfig memory tokenConfig = tokens[index - 1];
        require(amount >= tokenConfig.lowerBound, "amount should not be less than lower bound");
        require(amount <= tokenConfig.upperBound, "amount should not be larger than upper bound");

        address payable relayerAddr = payable(tokenConfig.relayer);

        relayerAddr.transfer(msg.value);

        bool success = IBEP20(contractAddr).transferFrom(msg.sender, relayerAddr, amount);
        require(success, "transfer token failed");

        emit tokenTransfer(contractAddr, relayerAddr, amount);
        emit bnbTransfer(relayerAddr, msg.value);
        return true;
    }
}