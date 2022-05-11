// SPDX-License-Identifier: AGPL-3.0-or-later

/// DssProxyActionsRebalance.sol

// Copyright (C) 2022 Dai Foundation

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.6.12;

interface GemLike {
    function approve(address, uint256) external;
    function transfer(address, uint256) external;
    function transferFrom(address, address, uint256) external;
    function deposit() external payable;
    function withdraw(uint256) external;
}

interface ManagerLike {
    function cdpCan(address, uint256, address) external view returns (uint256);
    function ilks(uint256) external view returns (bytes32);
    function owns(uint256) external view returns (address);
    function urns(uint256) external view returns (address);
    function vat() external view returns (address);
    function open(bytes32, address) external returns (uint256);
    function give(uint256, address) external;
    function cdpAllow(uint256, address, uint256) external;
    function urnAllow(address, uint256) external;
    function frob(uint256, int256, int256) external;
    function flux(uint256, address, uint256) external;
    function move(uint256, address, uint256) external;
    function exit(address, uint256, address, uint256) external;
    function quit(uint256, address) external;
    function enter(address, uint256) external;
    function shift(uint256, uint256) external;
}

interface VatLike {
    function can(address, address) external view returns (uint256);
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
    function dai(address) external view returns (uint256);
    function urns(bytes32, address) external view returns (uint256, uint256);
    function frob(bytes32, address, address, address, int256, int256) external;
    function hope(address) external;
    function nope(address) external;
    function move(address, address, uint256) external;
}

interface GemJoinLike {
    function dec() external returns (uint256);
    function gem() external returns (GemLike);
    function join(address, uint256) external payable;
    function exit(address, uint256) external;
}

interface FlashLike {
    function vatDaiFlashLoan(address receiver, uint256 amount, bytes calldata data) external;
}

contract DssProxyActionsRebalance {
    VatLike immutable public vat;
    ManagerLike immutable public manager;
    address immutable public thisContract;

    constructor(address vat_, address manager_) public {
        vat = VatLike(vat_);
        manager = ManagerLike(manager_);
        thisContract = address(this);
    }

    function _mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "mul-overflow");
    }

    function _divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x != 0 ? ((x - 1) / y) + 1 : 0;
    }

    function _toInt256(uint256 x) internal pure returns (int256 y) {
        y = int256(x);
        require(y >= 0, "int-overflow");
    }

    function _rate(uint256 cdp) internal view returns (uint256 rate) {
        (, rate,,,) = vat.ilks(manager.ilks(cdp));
    }

    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // WARNING: This function is meant to be used as a a library for a DSProxy. Don't call it directly.
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    function rebalance(
        address flash,
        address joinFrom,
        uint256 cdpFrom,
        address joinTo,
        uint256 cdpTo
    ) external {
        bytes32 ilk = manager.ilks(cdpFrom);
        (uint256 ink, uint256 art) = vat.urns(ilk, manager.urns(cdpFrom));
        (, uint256 rate,,,) = vat.ilks(ilk);

        vat.hope(thisContract);
        FlashLike(flash).vatDaiFlashLoan(thisContract, _mul(art, rate), abi.encode(joinFrom, cdpFrom, joinTo, cdpTo, ink, art));
        vat.nope(thisContract);
    }

    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // WARNING: This function is meant to be used as callback for rebalance. Don't use it at all.
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    function onVatDaiFlashLoan(
        address initiator,
        uint256 amount,
        uint256,
        bytes calldata data
    ) external {
        (address joinFrom, uint256 cdpFrom, address joinTo, uint256 cdpTo, uint256 ink, uint256 art) = abi.decode(data, (address, uint256, address, uint256, uint256, uint256));
        
        manager.frob(
            cdpFrom,
            -_toInt256(ink),
            -_toInt256(art)
        );

        GemJoinLike(joinFrom).exit(address(this), ink);

        GemJoinLike(joinTo).gem().approve(address(joinTo), type(uint256).max);
        GemJoinLike(joinTo).join(address(this), ink);

        manager.frob(
            cdpTo,
            _toInt256(ink),
            _toInt256(_divup(amount, _rate(cdpTo)))
        );

        vat.move(address(this), initiator, amount);
    }
}
