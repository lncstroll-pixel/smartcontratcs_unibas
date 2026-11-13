// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts@4.9.6/token/ERC20/extensions/ERC20Votes.sol";

/// @notice Fixer Beteiligungspool mit frei uebertragbaren, delegierbaren Stimmen.
contract EquityToken is ERC20Votes {
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply,
        uint256 _companyAllocation,
        address _company,
        address _reserve
    ) ERC20(_name, _symbol) ERC20Permit(_name) {
        require(_company != address(0) && _reserve != address(0), "Zero address");
        require(_company != _reserve, "Identical recipients");
        require(_totalSupply > 0 && _totalSupply <= type(uint224).max, "Invalid supply");
        require(_companyAllocation > 0 && _companyAllocation < _totalSupply, "Invalid allocation");

        // Die einzigen Mint-Aufrufe: nach dem Konstruktor bleibt die Menge fest.
        _mint(_company, _companyAllocation);
        _mint(_reserve, _totalSupply - _companyAllocation);
    }

    function decimals() public pure override returns (uint8) {
        return 0;
    }
}
