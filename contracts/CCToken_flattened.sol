
// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
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

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
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
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol


// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.20;


/**
 * @dev Interface for the optional metadata functions from the ERC-20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts/interfaces/draft-IERC6093.sol


// OpenZeppelin Contracts (last updated v5.1.0) (interfaces/draft-IERC6093.sol)
pragma solidity ^0.8.20;

/**
 * @dev Standard ERC-20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC-721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in ERC-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC-1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}

// File: @openzeppelin/contracts/token/ERC20/ERC20.sol


// OpenZeppelin Contracts (last updated v5.3.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.20;





/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC-20
 * applications.
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * Both values are immutable: they can only be set once during construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Skips emitting an {Approval} event indicating an allowance update. This is not
     * required by the ERC. See {xref-ERC20-_approve-address-address-uint256-bool-}[_approve].
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner`'s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     *
     * ```solidity
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner`'s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: @openzeppelin/contracts/security/ReentrancyGuard.sol


// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

// File: contracts/CCK/ERC3643.sol


pragma solidity ^0.8.0;

/**
 * @title IERC3643
 * @dev Interface for on-chain identity management and compliance.
 */
interface IERC3643 {
    /**
     * @dev Returns the on-chain ID of the contract.
     * @return address The address of the contract.
     */
    function onchainID() external view returns (address);
    
    /**
     * @dev Returns the version of the contract.
     * @return string The version string.
     */
    function version() external view returns (string memory);
    
    /**
     * @dev Returns the identity registry address.
     * @return address The identity registry address.
     */
    function identityRegistry() external view returns (address);
    
    /**
     * @dev Returns the compliance address.
     * @return address The compliance address.
     */
    function compliance() external view returns (address);
    
    /**
     * @dev Checks if the contract is paused.
     * @return bool Indicates if the contract is paused.
     */
    function paused() external view returns (bool);
    
    /**
     * @dev Checks if a user is frozen.
     * @param userAddress Address of the user to check.
     * @return bool Indicates if the user is frozen.
     */
    function isFrozen(address userAddress) external view returns (bool);
    
    /**
     * @dev Returns the number of frozen tokens for a user.
     * @param userAddress Address of the user to check.
     * @return uint256 Amount of frozen tokens.
     */
    // function getFrozenTokens(address userAddress) external view returns (uint256);
}
// File: contracts/CCToken.sol


pragma solidity ^0.8.24;






contract CCKToken is ERC20, Ownable, IERC3643, ReentrancyGuard {
    uint256 public TOTAL_SUPPLY = 300_000_000 * 10**18; // Integer units (decimals = 0)
    mapping(address => bool) public whitelist;
    mapping(address => bool) public frozen;
    uint256 public mintedAmount;
    string public tokenName;
    uint256 public constant EXCHANGE_RATE = 20;
    mapping(address => bool) public voters;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public constant TOTAL_VOTES_REQUIRED = 5;
    uint256 public constant MIN_VOTES_FOR_USER_ACTIONS = 3;
    uint256 public constant MIN_VOTES_FOR_MINT = 2;
    address[] public votersList;

    enum ProposalType { Name, TotalSupply, Voters, WhitelistAdd, WhitelistRemove, Freeze, Unfreeze, Mint, ToggleWhitelistCheck }

    struct Proposal {
        ProposalType proposalType;
        address initiator;
        uint256 voteCount;
        uint256 timestamp;
        address target;
        uint256 value;
        string name;
        address[] oldVoters;
        address[] newVoters;
        bool active;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 internal proposalCount;
    bool public votingPaused;
    bool public contractPaused;
    uint256 public lastDistributionTimestamp;
    uint256 public constant DISTRIBUTION_INTERVAL = 300;
    uint256 public constant DISTRIBUTION_AMOUNT = 1; // Integer units
    uint256 public lastAutoBatchMintTimestamp;
    uint256 public constant AUTO_BATCH_MINT_INTERVAL = 15 minutes;
    uint256 public constant BATCH_MINT_AMOUNT = 100; // Integer units
    bool public whitelistCheckEnabled = false;

    event ProposalCreated(uint256 indexed proposalId, ProposalType proposalType, address initiator);
    event ProposalExecuted(uint256 indexed proposalId, ProposalType proposalType);
    event ProposalCancelled(uint256 indexed proposalId, ProposalType proposalType);
    event NameChanged(string newName);
    event TotalSupplyAdjusted(uint256 newTotalSupply);
    event VotersChanged(address[] oldVoters, address[] newVoters);
    event StatusChanged(address indexed target, string statusType, bool status);
    event MintExecuted(address to, uint256 amount);
    event WhitelistDistribution(uint256 amount);
    event VotingPaused();
    event VotingResumed();
    event ContractPaused();
    event ContractResumed();
    event Exchange(address indexed user, uint256 inputAmount, uint256 cckAmount, address indexed targetAddress);
    event BatchMint(address[] indexed recipients, uint256 amountPerAddress, bool isAuto);
    event VoteCast(uint256 indexed proposalId, address indexed voter);
    event WhitelistCheckToggled(bool enabled);
    event Deposit(address indexed from, address indexed token, address indexed to, uint256 amount);

    constructor(
        string memory initialName,
        address[] memory _whitelist,
        address[] memory _voters
    ) ERC20(initialName, "CC") Ownable(msg.sender) {
        require(_whitelist.length > 0, "Whitelist cannot be empty");
        require(_voters.length > 0, "Voters list cannot be empty");

        for (uint256 i = 0; i < _whitelist.length; i++) {
            require(_whitelist[i] != address(0), "Invalid whitelist address");
            whitelist[_whitelist[i]] = true;
        }

        for (uint256 i = 0; i < _voters.length; i++) {
            require(_voters[i] != address(0), "Invalid voter address");
            voters[_voters[i]] = true;
            votersList.push(_voters[i]);
        }

        tokenName = initialName;
        lastDistributionTimestamp = block.timestamp;
        lastAutoBatchMintTimestamp = block.timestamp;
    }

    function _batchMintToWhitelist(address[] memory whitelistAddresses, uint256 amount) internal {
        require(whitelistAddresses.length > 0, "Whitelist addresses cannot be empty");
        uint256 totalMintAmount = whitelistAddresses.length * amount;
        require(mintedAmount + totalMintAmount <= TOTAL_SUPPLY, "Exceeds total supply");

        for (uint256 i = 0; i < whitelistAddresses.length; i++) {
            address recipient = whitelistAddresses[i];
            require(recipient != address(0), "Invalid recipient address");
            require(whitelist[recipient], "Recipient not whitelisted");
            _mint(recipient, amount);
        }
        mintedAmount += totalMintAmount;
    }

    function autoBatchMintToWhitelist(address[] memory whitelistAddresses) external nonReentrant {
        require(!contractPaused, "Contract paused");
        require(block.timestamp >= lastAutoBatchMintTimestamp + AUTO_BATCH_MINT_INTERVAL, "Too soon for auto mint");
        _batchMintToWhitelist(whitelistAddresses, BATCH_MINT_AMOUNT);
        lastAutoBatchMintTimestamp = block.timestamp;
        emit BatchMint(whitelistAddresses, BATCH_MINT_AMOUNT, true);
    }

    function manualBatchMintToWhitelist(address[] memory whitelistAddresses) external nonReentrant {
        require(!contractPaused, "Contract paused");
        require(voters[msg.sender], "Not a voter");
        _batchMintToWhitelist(whitelistAddresses, BATCH_MINT_AMOUNT);
        emit BatchMint(whitelistAddresses, BATCH_MINT_AMOUNT, false);
    }

    function exchange(uint256 inputAmount, address targetAddress) external nonReentrant {
        require(!contractPaused, "Contract paused");
        if (whitelistCheckEnabled) {
            require(whitelist[targetAddress], "Target not whitelisted");
        }
        require(inputAmount > 0, "Input amount must be greater than 0");

        uint256 cckAmount = inputAmount * EXCHANGE_RATE;
        require(cckAmount > 0, "CCK amount must be greater than 0");
        require(mintedAmount + cckAmount <= TOTAL_SUPPLY, "Exceeds total supply");

        _mint(targetAddress, cckAmount);
        mintedAmount += cckAmount;
        emit Exchange(msg.sender, inputAmount, cckAmount, targetAddress);
    }

    function deposit(address tokenAddress, address target, uint256 amount, uint8 tokenDecimals, uint256 exchangeRate) external nonReentrant returns (bool success) {
        require(!contractPaused, "Contract paused");
        require(amount > 0, "Amount must be greater than 0");
        require(target != address(0), "Invalid target address");
        require(tokenAddress != address(0), "Invalid token address");
        require(tokenDecimals <= 78, "Invalid token decimals"); // Prevent overflow
        require(exchangeRate > 0, "Exchange rate must be greater than 0");
        if (whitelistCheckEnabled) {
            require(whitelist[msg.sender], "Sender not whitelisted");
        }
        require(!frozen[msg.sender], "Sender account is frozen");

        // Transfer external token to target address
        IERC20 token = IERC20(tokenAddress);
        require(token.transferFrom(msg.sender, target, amount), "External token transfer failed");

        // Calculate CCK amount: base amount (adjusted for token decimals) * exchange rate
        uint256 baseAmount = amount / (10 ** tokenDecimals); // Convert to integer units of external token
        uint256 cckAmount = baseAmount * exchangeRate; // Apply exchange rate
        require(cckAmount > 0, "CCK amount must be greater than 0");
        require(mintedAmount + cckAmount <= TOTAL_SUPPLY, "Exceeds total supply");
        _mint(msg.sender, cckAmount);
        mintedAmount += cckAmount;

        emit Deposit(msg.sender, tokenAddress, target, cckAmount);
        return true;
    }

    function propose(
        ProposalType proposalType,
        address target,
        uint256 value,
        string memory name,
        address[] memory oldVoters,
        address[] memory newVoters
    ) external {
        require(!contractPaused, "Contract paused");
        require(voters[msg.sender], "Not a voter");

        if (proposalType == ProposalType.Name) {
            require(bytes(name).length > 0, "Name cannot be empty");
        } else if (proposalType == ProposalType.TotalSupply) {
            require(value != 0, "Value cannot be zero");
            require(int256(TOTAL_SUPPLY) + int256(value) >= int256(mintedAmount), "Invalid total supply");
            require(int256(TOTAL_SUPPLY) + int256(value) >= 0, "Total supply cannot be negative");
        } else if (proposalType == ProposalType.Voters) {
            require(oldVoters.length == newVoters.length && oldVoters.length > 0, "Invalid voters list");
            for (uint256 i = 0; i < oldVoters.length; i++) {
                require(voters[oldVoters[i]], "Old voter not found");
                require(newVoters[i] != address(0) && !voters[newVoters[i]], "Invalid new voter");
                for (uint256 j = i + 1; j < newVoters.length; j++) {
                    require(newVoters[i] != newVoters[j], "Duplicate new voters");
                }
            }
        } else if (proposalType == ProposalType.WhitelistAdd) {
            require(target != address(0) && !whitelist[target], "Invalid or already whitelisted");
        } else if (proposalType == ProposalType.WhitelistRemove) {
            require(whitelist[target], "Target not whitelisted");
        } else if (proposalType == ProposalType.Freeze) {
            require(target != address(0) && !frozen[target], "Invalid or already frozen");
        } else if (proposalType == ProposalType.Unfreeze) {
            require(frozen[target], "Target not frozen");
        } else if (proposalType == ProposalType.Mint) {
            require(whitelist[target] && target != address(0), "Invalid or not whitelisted");
            require(value > 0 && mintedAmount + value <= TOTAL_SUPPLY, "Invalid mint amount");
        } else if (proposalType == ProposalType.ToggleWhitelistCheck) {
            require(value <= 1, "Invalid value");
            require(target == address(0) && bytes(name).length == 0 && oldVoters.length == 0 && newVoters.length == 0, "Invalid parameters");
        }

        proposals[proposalCount] = Proposal({
            proposalType: proposalType,
            initiator: msg.sender,
            voteCount: 0,
            timestamp: proposalType <= ProposalType.Voters ? block.timestamp + 10 seconds : block.timestamp,
            // timestamp: proposalType <= ProposalType.Voters ? block.timestamp + 48 hours : block.timestamp,
            target: target,
            value: value,
            name: name,
            oldVoters: oldVoters,
            newVoters: newVoters,
            active: true
        });

        emit ProposalCreated(proposalCount, proposalType, msg.sender);
        proposalCount++;
    }

    function vote(uint256 proposalId) external {
        require(!contractPaused, "Contract paused");
        require(voters[msg.sender], "Not a voter");
        Proposal storage proposal = proposals[proposalId];
        require(proposal.active, "Proposal not active");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        require(!votingPaused, "Voting paused");

        hasVoted[proposalId][msg.sender] = true;
        proposal.voteCount++;

        uint256 requiredVotes = proposal.proposalType == ProposalType.Mint || proposal.proposalType == ProposalType.ToggleWhitelistCheck ?
                                MIN_VOTES_FOR_MINT : (proposal.proposalType >= ProposalType.WhitelistAdd && 
                                proposal.proposalType <= ProposalType.Unfreeze ? MIN_VOTES_FOR_USER_ACTIONS : TOTAL_VOTES_REQUIRED);
        require(proposal.voteCount <= requiredVotes, "Too many votes");

        emit VoteCast(proposalId, msg.sender);
    }

    function _checkProposalVotes(Proposal storage proposal) internal view returns (uint256) {
        require(proposal.active, "Proposal not active");
        require(block.timestamp >= proposal.timestamp, "Proposal not ready");
        uint256 requiredVotes = proposal.proposalType == ProposalType.Mint || proposal.proposalType == ProposalType.ToggleWhitelistCheck ?
                                MIN_VOTES_FOR_MINT : (proposal.proposalType == ProposalType.WhitelistAdd || 
                                proposal.proposalType == ProposalType.WhitelistRemove || proposal.proposalType == ProposalType.Freeze || 
                                proposal.proposalType == ProposalType.Unfreeze ? MIN_VOTES_FOR_USER_ACTIONS : TOTAL_VOTES_REQUIRED);
        require(proposal.voteCount >= requiredVotes, "Insufficient votes");
        return requiredVotes;
    }

    function executeProposal(uint256 proposalId) external {
        require(!contractPaused, "Contract paused");
        Proposal storage proposal = proposals[proposalId];
        _checkProposalVotes(proposal);

        if (proposal.proposalType == ProposalType.Name) {
            _setName(proposal.name);
            emit NameChanged(proposal.name);
        } else if (proposal.proposalType == ProposalType.TotalSupply) {
            TOTAL_SUPPLY = uint256(int256(TOTAL_SUPPLY) + int256(proposal.value));
            emit TotalSupplyAdjusted(TOTAL_SUPPLY);
        } else if (proposal.proposalType == ProposalType.Voters) {
            address[] memory tempVotersList = votersList;
            for (uint256 i = 0; i < proposal.oldVoters.length; i++) {
                voters[proposal.oldVoters[i]] = false;
                voters[proposal.newVoters[i]] = true;
                for (uint256 j = 0; j < tempVotersList.length; j++) {
                    if (tempVotersList[j] == proposal.oldVoters[i]) {
                        tempVotersList[j] = proposal.newVoters[i];
                        break;
                    }
                }
            }
            votersList = tempVotersList;
            emit VotersChanged(proposal.oldVoters, proposal.newVoters);
        } else if (proposal.proposalType == ProposalType.WhitelistAdd) {
            whitelist[proposal.target] = true;
            emit StatusChanged(proposal.target, "Whitelist", true);
        } else if (proposal.proposalType == ProposalType.WhitelistRemove) {
            whitelist[proposal.target] = false;
            emit StatusChanged(proposal.target, "Whitelist", false);
        } else if (proposal.proposalType == ProposalType.Freeze) {
            frozen[proposal.target] = true;
            emit StatusChanged(proposal.target, "Freeze", true);
        } else if (proposal.proposalType == ProposalType.Unfreeze) {
            frozen[proposal.target] = false;
            emit StatusChanged(proposal.target, "Freeze", false);
        } else if (proposal.proposalType == ProposalType.Mint) {
            _mint(proposal.target, proposal.value);
            mintedAmount += proposal.value;
            emit MintExecuted(proposal.target, proposal.value);
        } else if (proposal.proposalType == ProposalType.ToggleWhitelistCheck) {
            whitelistCheckEnabled = proposal.value == 1;
            emit WhitelistCheckToggled(proposal.value == 1);
        }

        resetVotes(proposalId);
        delete proposals[proposalId];
        emit ProposalExecuted(proposalId, proposal.proposalType);
    }

    function cancelProposal(uint256 proposalId) external {
        require(!contractPaused, "Contract paused");
        Proposal storage proposal = proposals[proposalId];
        require(proposal.active, "Proposal not active");
        require(msg.sender == proposal.initiator, "Not initiator");
        require(proposal.proposalType <= ProposalType.Voters, "Cannot cancel this proposal type");
        require(block.timestamp < proposal.timestamp, "Proposal time expired");

        resetVotes(proposalId);
        ProposalType cancelledType = proposal.proposalType;
        delete proposals[proposalId];
        emit ProposalCancelled(proposalId, cancelledType);
    }

    function resetVotes(uint256 proposalId) internal {
        for (uint256 i = 0; i < votersList.length; i++) {
            if (hasVoted[proposalId][votersList[i]]) {
                hasVoted[proposalId][votersList[i]] = false;
            }
        }
    }

    function getActiveProposals() external view returns (uint256[] memory ids) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < proposalCount; i++) {
            if (proposals[i].active) {
                activeCount++;
            }
        }

        ids = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < proposalCount; i++) {
            if (proposals[i].active) {
                ids[index] = i;
                index++;
            }
        }
    }

    function distributeToWhitelist() external {
        require(!contractPaused, "Contract paused");
        require(voters[msg.sender], "Not a voter");
        require(block.timestamp >= lastDistributionTimestamp + DISTRIBUTION_INTERVAL, "Too soon for distribution");
        require(mintedAmount + DISTRIBUTION_AMOUNT <= TOTAL_SUPPLY, "Exceeds total supply");

        lastDistributionTimestamp = block.timestamp;
        emit WhitelistDistribution(DISTRIBUTION_AMOUNT);
    }

    function pauseVoting() external onlyOwner {
        votingPaused = true;
        emit VotingPaused();
    }

    function resumeVoting() external onlyOwner {
        votingPaused = false;
        emit VotingResumed();
    }

    function pauseContract() external {
        require(voters[msg.sender], "Not a voter");
        require(!contractPaused, "Contract already paused");
        contractPaused = true;
        emit ContractPaused();
    }

    function resumeContract() external {
        require(voters[msg.sender], "Not a voter");
        contractPaused = false;
        emit ContractResumed();
    }

    function remainingSupply() external view returns (uint256) {
        return TOTAL_SUPPLY - mintedAmount;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        require(!contractPaused, "Contract paused");
        require(!frozen[msg.sender], "Sender frozen");
        require(amount == uint256(uint128(amount)), "Amount too large");

        bool success = super.transfer(to, amount);
        if (success && to == address(this)) {
            _mint(msg.sender, amount);
        }
        return success;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        require(!contractPaused, "Contract paused");
        require(!frozen[sender], "Sender frozen");
        require(amount == uint256(uint128(amount)), "Amount too large");

        bool success = super.transferFrom(sender, recipient, amount);
        if (success && recipient == address(this)) {
            _mint(sender, amount);
        }
        return success;
    }

    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    function balanceOfUser(address user) external view returns (uint256) {
        return balanceOf(user);
    }

    function onchainID() external view override returns (address) {
        return address(this);
    }

    function version() external pure override returns (string memory) {
        return "1.0.0";
    }

    function identityRegistry() external pure override returns (address) {
        return address(0);
    }

    function compliance() external pure override returns (address) {
        return address(0);
    }

    function paused() external view override returns (bool) {
        return contractPaused;
    }

    function isFrozen(address userAddress) external view override returns (bool) {
        return frozen[userAddress];
    }

    function _setName(string memory newName) internal {
        tokenName = newName;
    }

    function getProposalCount() public view returns (uint256) {
        return proposalCount > 0 ? proposalCount - 1 : 0;
    }

    function getWhitelistCheckEnabled() public view returns (bool) {
        return whitelistCheckEnabled;
    }
}