// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./SpaceCoinToken.sol";

/**
 * @title SpaceCoinICO
 * @author TheV
 */
contract SpaceCoinICO is ReentrancyGuard {
    uint256 public constant EXCHANGE_RATE = 5;
    uint256 public constant ICO_TARGET = 30000 ether;
    uint256 public totalRaised = 0 ether;
    address public owner;
    SpaceCoinToken public token;
    mapping(address => uint256) public preOpenInvestorsBalances;
    mapping(address => bool) public whitelistedInvestors;
    address[] public investorsWithContributions;
    bool public fundraisingEnabled = false;
    uint8 public currentPhase = 0;
    bool public closedICO = false;

    struct Phase {
        string code;
        uint256 target;
        uint256 individualTotalCap;
        uint256 collected;
        bool shouldReleaseTokens;
        bool openToAll;
    }

    Phase[3] public phases;

    event SpaceCoinICOCreated(address icoAddress, address tokenAddress, address owner, uint256 target);
    event FoundraisingEnabledChanged(bool enabled);
    event FundReceived(address indexed investor, uint256 amount);
    event PhaseChanged(string code);
    event PreOpenPhaseTokenReleased();
    event ICOClosed(address treasury);

    modifier onlyOwner() {
        require(msg.sender == owner, "E_OWNER_ONLY");
        _;
    }

    modifier onlyOpen() {
        require(!closedICO, "E_ICO_CLOSED");
        _;
    }

    /**
     * @notice Build the ICO for a specific token with a specified set of investors
     * @param _tokenAddress Address of the token to be used in the ICO, must be IECR20 compliant
     * @param _whitelist The address of the treasury
     */
    constructor(address _tokenAddress, address[] memory _whitelist) {
        owner = msg.sender;
        token = SpaceCoinToken(_tokenAddress);

        phases[0] = Phase("SEED", 15000 ether, 1500 ether, 0 ether, false, false);
        phases[1] = Phase("GENERAL", 30000 ether, 1000 ether, 0 ether, false, true);
        phases[2] = Phase("OPEN", 30000 ether, 2**256 - 1, 0 ether, true, true);

        _whitelistAddresses(_whitelist);
        emit SpaceCoinICOCreated(address(this), _tokenAddress, owner, ICO_TARGET);
    }

    /**
     * @notice Allow the owner to toggle the fund acceptance
     */
    function toggleFundraisingEnabled() external onlyOwner onlyOpen {
        fundraisingEnabled = !fundraisingEnabled;
        emit FoundraisingEnabledChanged(fundraisingEnabled);
    }

    /**
     * @notice Allow the owner to add investors to the whitelist
     */
    function addAddressesToWhitelist(address[] memory _whitelist) external onlyOwner onlyOpen {
        _whitelistAddresses(_whitelist);
    }

    /**
     * @notice Allow the owner to advance to the next phase
     * @dev This function transfers the tokens if the phase is market as releasing tokens
     */
    function moveToPhase(uint8 phase) external onlyOwner onlyOpen nonReentrant {
        require(phase > currentPhase && phase < phases.length, "E_PHASE_INVALID");
        currentPhase = phase;
        emit PhaseChanged(phases[currentPhase].code);
    }

    /**
     * @notice Allow investors to contribute to the ICO
     * @dev when the current phase allows for token to be distributed,
       it will automatically transfer tokens to the investor.
       This is not releasing the pre-open phase tokens, investors must
       call withdrawTokens to release their pre-open phase tokens.
     */
    function invest() external payable nonReentrant onlyOpen {
        require(fundraisingEnabled, "E_FUNDRAISING_DISABLED");
        require(whitelistedInvestors[msg.sender] || phases[currentPhase].openToAll, "E_NOT_WHITELISTED");
        require(
            preOpenInvestorsBalances[msg.sender] + msg.value <= phases[currentPhase].individualTotalCap,
            "E_INDIVIDUAL_CAP_OVERFLOW"
        );
        require(phases[currentPhase].collected + msg.value <= phases[currentPhase].target, "E_PHASE_TARGET_REACHED");
        require(totalRaised + msg.value <= ICO_TARGET, "E_TOTAL_TARGET_OVERFLOW");

        totalRaised += msg.value;
        phases[currentPhase].collected += msg.value;
        emit FundReceived(msg.sender, msg.value);

        if (phases[currentPhase].shouldReleaseTokens) {
            _transferTokens(msg.sender, msg.value);
        } else {
            preOpenInvestorsBalances[msg.sender] += msg.value;
        }
    }

    /**
     * @notice Withdraw tokens from the ICO from pre-open phase
     * @dev This function is meant to be used by pre-open investors to get their well deserved tokens
     * it is the only contract interaction available after closing the ICO
     * @param _amountInEth Amount of tokens to be transferred in ETH
     */
    function withdrawTokens(uint256 _amountInEth) external nonReentrant {
        require(phases[currentPhase].shouldReleaseTokens, "E_PHASE_NOT_RELEASING_TOKENS");
        require(preOpenInvestorsBalances[msg.sender] >= _amountInEth, "E_NOT_ENOUGH_TOKENS");
        preOpenInvestorsBalances[msg.sender] -= _amountInEth;
        _transferTokens(msg.sender, _amountInEth);
    }

    /**
     * @notice Transfers the tokens owned by the ICO contract to the investor
     * @param _to Address to which the tokens will be transferred
     * @param _amountInEth Amount of tokens to be transferred in ETH
     */
    function _transferTokens(address _to, uint256 _amountInEth) private {
        uint256 amountInSCP = _amountInEth * EXCHANGE_RATE;
        require(token.balanceOf(address(this)) >= amountInSCP, "E_NOT_ENOUGH_SPC");
        bool success = token.transfer(_to, amountInSCP);
        require(success, "E_TRANSFER_FAILED");
    }

    /**
     * @dev Allow modification to the whitelisted investors
     * @param _whitelist List of address of investors to be whitelisted
     */
    function _whitelistAddresses(address[] memory _whitelist) private {
        for (uint256 i = 0; i < _whitelist.length; i++) {
            whitelistedInvestors[_whitelist[i]] = true;
        }
    }

    /**
     * @notice Allow the owner to transfer ETH to the treasury, closing the ICO
     * @dev Closing the ICO is only possible if the ICO has reached the OPEN phase, so investors
     * would be able to withdraw their tokens.
     */
    function closeIPO(address payable _treasuryAddress) external onlyOwner onlyOpen nonReentrant {
        require(phases[currentPhase].shouldReleaseTokens, "E_PHASE_INVALID_FOR_CLOSING");
        require(totalRaised > 0, "E_ICO_NOT_CLOSEABLE");
        emit ICOClosed(_treasuryAddress);
        closedICO = true;
        fundraisingEnabled = false;
        _treasuryAddress.transfer(totalRaised);
    }
}
