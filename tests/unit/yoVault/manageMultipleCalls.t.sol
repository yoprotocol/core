// solhint-disable
// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Errors } from "src/libraries/Errors.sol";

import { Base_Test } from "../../Base.t.sol";
import { MockTarget } from "../../mocks/MockTarget.sol";
import { MockAuthority } from "../../mocks/MockAuthority.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ManageMultipleCalls_Unit_Concrete_Test is Base_Test {
    uint256 internal value = 1 ether;
    address[] internal mockTargets;
    bytes4 internal targetfunctionSig = MockTarget.someFunction.selector;
    bytes internal data = abi.encodeWithSelector(MockTarget.someFunction.selector, uint256(42));

    function setUp() public override {
        Base_Test.setUp();

        vm.deal(address(depositVault), value); // Fund the vault with native assets

        mockTargets.push(address(new MockTarget()));
        mockTargets.push(address(new MockTarget()));

        vm.startPrank({ msgSender: users.admin });

        for (uint256 i = 0; i < mockTargets.length; i++) {
            MockAuthority(address(depositVault.authority())).setRoleCapability(
                ADMIN_ROLE, mockTargets[i], targetfunctionSig, true
            );
        }
    }

    function test_ManageMultipleCall_Success() public {
        _manage();
        for (uint256 i = 0; i < mockTargets.length; i++) {
            uint256 result = MockTarget(mockTargets[i]).value();
            assertEq(result, 42, "Function was not called correctly.");
        }
    }

    function test_ManageMultipleCall_Revert_Unauthorized() public {
        vm.startPrank({ msgSender: users.bob }); // Stop acting as the owner
        vm.expectRevert("UNAUTHORIZED");
        _manage();
    }

    function test_ManageMultipleCall_Revert_TargetMethodNotAuthorized() public {
        // Remove the capability
        for (uint256 i = 0; i < mockTargets.length; i++) {
            MockAuthority(address(depositVault.authority())).setRoleCapability(
                ADMIN_ROLE, mockTargets[i], targetfunctionSig, false
            );
        }

        vm.expectRevert(
            abi.encodeWithSelector(Errors.TargetMethodNotAuthorized.selector, mockTargets[0], targetfunctionSig)
        );
        _manage();
    }

    function _manage() internal {
        bytes[] memory datas = new bytes[](mockTargets.length);
        uint256[] memory values = new uint256[](mockTargets.length);
        for (uint256 i = 0; i < mockTargets.length; i++) {
            datas[i] = data;
            values[i] = 0;
        }

        depositVault.manage(mockTargets, datas, values);
    }
}
