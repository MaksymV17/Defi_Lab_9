// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title SimpleDAO - спрощений контракт управління (Лабораторна робота №9)
/// @notice Пропозиції створюються, за них голосують власники governance-токена,
///         після завершення голосування пропозиція виконується викликом цільового контракту.
contract SimpleDAO {
    struct Proposal {
        address target;       // контракт, який буде викликано
        bytes data;           // закодований виклик (наприклад, setFee(10))
        string description;   // опис пропозиції
        uint256 deadline;     // кінець голосування
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
    }

    // Для тестування: 1 хвилина замість 3 днів
    uint256 public constant VOTING_PERIOD = 1 minutes;

    IERC20 public immutable governanceToken;
    uint256 public proposalCount;

    mapping(uint256 => Proposal) private _proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed id, address indexed proposer, address target, string description, uint256 deadline);
    event Voted(uint256 indexed id, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed id);

    constructor(address governanceToken_) {
        require(governanceToken_ != address(0), "DAO: zero token");
        governanceToken = IERC20(governanceToken_);
    }

    /// @notice Створити пропозицію (мінімум токенів не вимагається, це спрощена модель)
    function createProposal(address target, bytes calldata data, string calldata description)
        external
        returns (uint256 id)
    {
        require(target != address(0), "DAO: zero target");
        id = ++proposalCount;
        Proposal storage p = _proposals[id];
        p.target = target;
        p.data = data;
        p.description = description;
        p.deadline = block.timestamp + VOTING_PERIOD;
        emit ProposalCreated(id, msg.sender, target, description, p.deadline);
    }

    /// @notice Проголосувати: вага голосу = баланс governance-токена на момент голосування
    function vote(uint256 id, bool support) external {
        Proposal storage p = _proposals[id];
        require(p.deadline != 0, "DAO: no such proposal");
        require(block.timestamp < p.deadline, "DAO: voting ended");
        require(!hasVoted[id][msg.sender], "DAO: already voted");

        uint256 weight = governanceToken.balanceOf(msg.sender);
        require(weight > 0, "DAO: no voting power");

        hasVoted[id][msg.sender] = true;
        if (support) p.votesFor += weight;
        else p.votesAgainst += weight;
        emit Voted(id, msg.sender, support, weight);
    }

    /// @notice Виконати пропозицію після завершення голосування, якщо "за" більше ніж "проти"
    function executeProposal(uint256 id) external {
        Proposal storage p = _proposals[id];
        require(p.deadline != 0, "DAO: no such proposal");
        require(block.timestamp >= p.deadline, "DAO: voting not ended");
        require(!p.executed, "DAO: already executed");
        require(p.votesFor > p.votesAgainst, "DAO: proposal rejected");

        p.executed = true;
        (bool ok, ) = p.target.call(p.data);
        require(ok, "DAO: execution failed");
        emit ProposalExecuted(id);
    }

    function getProposal(uint256 id) external view returns (
        address target, bytes memory data, string memory description,
        uint256 deadline, uint256 votesFor, uint256 votesAgainst, bool executed
    ) {
        Proposal storage p = _proposals[id];
        return (p.target, p.data, p.description, p.deadline, p.votesFor, p.votesAgainst, p.executed);
    }
}
