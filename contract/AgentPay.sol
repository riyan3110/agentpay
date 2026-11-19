// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title AgentPay — pay, escrow and invoice BNB by Agent ID handle.
/// @notice Built for the Binance Wallet x BNB Chain Agent ID Hackathon.
///         All identity comes from the official SPACE ID Agent ID registry
///         (0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F) resolved ON-CHAIN
///         inside every transaction. There is no owner, no fee, no admin
///         power over user funds. All forwarding is recipient-initiated or
///         explicitly visible in the caller's transaction.
interface IAgentID {
    /// @dev handle -> owner; returns address(0) when not registered.
    function ownerOfHandle(string calldata handle) external view returns (address);
    /// @dev owner -> handle; returns "" when the address holds no handle.
    function handleOf(address owner) external view returns (string memory);
    /// @dev ERC-721 balance; > 0 means the address holds an Agent ID.
    function balanceOf(address owner) external view returns (uint256);
}

contract AgentPay {
    IAgentID public constant AGENT_ID =
        IAgentID(0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F);

    string public constant NAME = "AgentPay";

    /// @notice One-time registration: links a wallet to the AgentPay directory.
    mapping(address => bool) public registered;
    uint256 public holderCount;

    /// @notice Escrow locked to a handle (soulbound identity = permanent claim right).
    /// handle => locked wei
    mapping(string => uint256) public escrowOf;
    /// @notice Total ever locked per handle, for stats.
    mapping(string => uint256) public escrowTotalOf;

    /// @notice Invoices: id => invoice
    struct Invoice {
        string handle;   // payee handle (resolved at payment time)
        uint256 amount;  // wei
        bool paid;
        string memo;
        uint256 createdAt;
    }
    uint256 public nextInvoiceId = 1;
    mapping(uint256 => Invoice) public invoices;

    event DirectoryJoined(address indexed wallet, string handle);
    event Paid(string indexed handle, address indexed from, address indexed to, uint256 amount, string memo);
    event EscrowLocked(string indexed handle, address indexed from, uint256 amount);
    event EscrowClaimed(string indexed handle, address indexed to, uint256 amount);
    event InvoiceCreated(uint256 indexed id, string indexed handle, uint256 amount, string memo);
    event InvoicePaid(uint256 indexed id, address indexed payer, address indexed payee, uint256 amount);

    /// @notice Join the public directory. Requires an Agent ID.
    function join() external {
        require(!registered[msg.sender], "already registered");
        require(AGENT_ID.balanceOf(msg.sender) > 0, "Agent ID required");
        registered[msg.sender] = true;
        holderCount += 1;
        emit DirectoryJoined(msg.sender, AGENT_ID.handleOf(msg.sender));
    }

    /// @notice Resolve a handle to its current owner (on-chain, live).
    function resolve(string calldata handle) external view returns (address) {
        return AGENT_ID.ownerOfHandle(handle);
    }

    /// @notice Reverse-resolve a wallet to its handle.
    function reverse(address wallet) external view returns (string memory) {
        return AGENT_ID.handleOf(wallet);
    }

    /// @notice Pay a handle directly. Resolution happens inside this
    ///         transaction; the recipient sees the funds immediately.
    function pay(string calldata handle, string calldata memo) external payable {
        _requireHandle(handle);
        address to = AGENT_ID.ownerOfHandle(handle);
        _forward(to, msg.value);
        emit Paid(handle, msg.sender, to, msg.value, memo);
    }

    /// @notice Lock BNB to a handle. Only the wallet that the registry
    ///         currently resolves the handle to can claim it.
    function lockEscrow(string calldata handle) external payable {
        _requireHandle(handle);
        require(msg.value > 0, "no value");
        escrowOf[handle] += msg.value;
        escrowTotalOf[handle] += msg.value;
        emit EscrowLocked(handle, msg.sender, msg.value);
    }

    /// @notice Claim escrow for your own handle.
    function claimEscrow() external {
        string memory handle = AGENT_ID.handleOf(msg.sender);
        require(bytes(handle).length > 0, "no handle");
        uint256 amount = escrowOf[handle];
        require(amount > 0, "nothing to claim");
        escrowOf[handle] = 0;
        _forward(msg.sender, amount);
        emit EscrowClaimed(handle, msg.sender, amount);
    }

    /// @notice Create an invoice payable to your own handle.
    function createInvoice(uint256 amount, string calldata memo) external returns (uint256 id) {
        string memory handle = AGENT_ID.handleOf(msg.sender);
        require(bytes(handle).length > 0, "no handle");
        require(amount > 0, "zero amount");
        id = nextInvoiceId++;
        invoices[id] = Invoice(handle, amount, false, memo, block.timestamp);
        emit InvoiceCreated(id, handle, amount, memo);
    }

    /// @notice Pay an invoice by id. Payee is resolved live at payment time.
    function payInvoice(uint256 id, string calldata memo) external payable {
        Invoice storage inv = invoices[id];
        require(inv.amount > 0, "no invoice");
        require(!inv.paid, "already paid");
        require(msg.value >= inv.amount, "underpaid");
        address payee = AGENT_ID.ownerOfHandle(inv.handle);
        inv.paid = true;
        _forward(payee, inv.amount);
        if (msg.value > inv.amount) {
            // return overpayment to the payer in the same transaction
            (bool ok, ) = msg.sender.call{value: msg.value - inv.amount}("");
            require(ok, "refund failed");
        }
        emit InvoicePaid(id, msg.sender, payee, inv.amount);
        if (bytes(memo).length > 0) emit Paid(inv.handle, msg.sender, payee, inv.amount, memo);
    }

    function _requireHandle(string calldata handle) internal view {
        require(bytes(handle).length > 0 && bytes(handle).length <= 32, "bad handle");
        require(AGENT_ID.ownerOfHandle(handle) != address(0), "unknown handle");
    }

    function _forward(address to, uint256 amount) internal {
        require(to != address(0), "unresolved");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "forward failed");
    }
}
