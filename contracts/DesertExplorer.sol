// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

error DesertExplorer__ContractClosed();
error DesertExplorer__NotTokenOwner();
error DesertExplorer__AlreadyOnExpedition();
error DesertExplorer__NotOnExpedition();
error DesertExplorer__ExpeditionNotDone();

interface IVGOLD {
    function mint(address account, uint256 amount) external;
}

interface IGenerals {
    function ownerOf(uint256 tokenId) external view returns (address owner);

    function mintGeneral(address to, uint256 quantity) external;
}

/**
 * @title A simple game that utilizes Verdomi Generals
 * @author Verdomi
 */
contract DesertExplorer is Ownable {
    /**
     * @notice The event that gets emitted once an expedition is completed
     * @param owner the owner of the Verdomi General (this address recieves the listed rewards)
     * @param tokenId the tokenId of the Verdomi General
     * @param vgold the amount of $VGOLD that was received
     * @param item the item that was received where 0=helmet, 1=armor, 2=weapon, 3=general, 4=none
     * @param ultra is 0 if item is ULTRA Rare or 1-9 if not
     */
    event ExpeditionCompleted(
        address owner,
        uint256 tokenId,
        uint256 vgold,
        uint256 item,
        uint256 ultra
    );

    IGenerals internal immutable i_generals;
    IVGOLD internal immutable i_vgold;

    mapping(address => uint256) private s_AddressToHelmet;
    mapping(address => uint256) private s_AddressToArmor;
    mapping(address => uint256) private s_AddressToWeapon;
    mapping(address => uint256) private s_AddressToUltraHelmet;
    mapping(address => uint256) private s_AddressToUltraArmor;
    mapping(address => uint256) private s_AddressToUltraWeapon;

    bool private s_isContractOpen = true;
    uint256 private s_expeditionTime;

    mapping(uint256 => uint256) private s_tokenToTime;

    constructor(address contractVGOLD, address contractGenerals, uint256 expeditionTime) {
        i_generals = IGenerals(contractGenerals);
        i_vgold = IVGOLD(contractVGOLD);
        s_expeditionTime = expeditionTime;
    }

    function toggleOpen() external onlyOwner {
        s_isContractOpen = !s_isContractOpen;
    }

    function setExpeditionTime(uint256 time) external onlyOwner {
        s_expeditionTime = time;
    }

    function startExpedition(uint256 tokenId) internal {
        // Make sure sender is owner of the token
        if (i_generals.ownerOf(tokenId) != msg.sender) {
            revert DesertExplorer__NotTokenOwner();
        }
        // Make sure token is not on expedition already
        if (s_tokenToTime[tokenId] > 0) {
            revert DesertExplorer__AlreadyOnExpedition();
        }

        s_tokenToTime[tokenId] = block.timestamp;
    }

    function completeExpedition(uint256 tokenId) internal {
        // Make sure token is on expedition
        if (s_tokenToTime[tokenId] == 0) {
            revert DesertExplorer__NotOnExpedition();
        }
        // Make sure the expedition is done
        if (s_tokenToTime[tokenId] + s_expeditionTime > block.timestamp) {
            revert DesertExplorer__ExpeditionNotDone();
        }

        s_tokenToTime[tokenId] = 0;
        address owner = i_generals.ownerOf(tokenId);

        // Select amount of $VGOLD
        uint256 amountVGOLD = (100 + randNum(401)) * 10 ** 18;

        i_vgold.mint(owner, amountVGOLD);

        // Potential treasure

        uint256 treasure = randNum(100);
        if (treasure < 5) {
            i_generals.mintGeneral(owner, 1);
            emit ExpeditionCompleted(owner, tokenId, amountVGOLD, 3, 1);
        } else if (treasure >= 25) {
            // Decide which item
            uint256 item = randNum(3);
            uint256 ultra = randNum(10);

            // Potential ULTRA Rare
            if (ultra == 0) {
                // Ultra Helmet
                if (item == 0) {
                    s_AddressToUltraHelmet[owner] += 1;

                    // Ultra Armor
                } else if (item == 1) {
                    s_AddressToUltraArmor[owner] += 1;

                    // Ultra Weapon
                } else {
                    s_AddressToUltraWeapon[owner] += 1;
                }
            } else {
                // Helmet
                if (item == 0) {
                    s_AddressToHelmet[owner] += 1;

                    // Armor
                } else if (item == 1) {
                    s_AddressToArmor[owner] += 1;

                    // Weapon
                } else {
                    s_AddressToWeapon[owner] += 1;
                }
            }
            emit ExpeditionCompleted(owner, tokenId, amountVGOLD, item, ultra);
        } else {
            // If no items are obtained, emit event with a 4 in the item slot and a 1 in the ultra slot
            emit ExpeditionCompleted(owner, tokenId, amountVGOLD, 4, 1);
        }
    }

    function startMultipleExpeditions(uint256[] calldata tokenIds) external {
        // Make sure that contract is open
        if (!s_isContractOpen) {
            revert DesertExplorer__ContractClosed();
        }
        uint256 length = tokenIds.length;
        for (uint256 i = 0; i < length; ) {
            startExpedition(tokenIds[i]);
            unchecked {
                i++;
            }
        }
    }

    function completeMultipleExpeditions(uint256[] calldata tokenIds) external {
        uint256 length = tokenIds.length;
        for (uint256 i = 0; i < length; ) {
            completeExpedition(tokenIds[i]);
            unchecked {
                i++;
            }
        }
    }

    function randNum(uint256 mod) internal view returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, gasleft()))) % mod);
    }

    // Getters
    function getHelmetAmount(address wallet) external view returns (uint256) {
        return s_AddressToHelmet[wallet];
    }

    function getArmorAmount(address wallet) external view returns (uint256) {
        return s_AddressToArmor[wallet];
    }

    function getWeaponAmount(address wallet) external view returns (uint256) {
        return s_AddressToWeapon[wallet];
    }

    function getUltraHelmetAmount(address wallet) external view returns (uint256) {
        return s_AddressToUltraHelmet[wallet];
    }

    function getUltraArmorAmount(address wallet) external view returns (uint256) {
        return s_AddressToUltraArmor[wallet];
    }

    function getUltraWeaponAmount(address wallet) external view returns (uint256) {
        return s_AddressToUltraWeapon[wallet];
    }

    function tokenExpeditionStart(uint256 tokenId) external view returns (uint256) {
        return s_tokenToTime[tokenId];
    }

    function isContractOpen() external view returns (bool) {
        return s_isContractOpen;
    }

    function getExpeditionTime() external view returns (uint256) {
        return s_expeditionTime;
    }

    function getVerdomiGeneralsAddress() external view returns (address) {
        return address(i_generals);
    }

    function getVgoldAddress() external view returns (address) {
        return address(i_vgold);
    }
}
