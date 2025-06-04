// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // ERC20 标准
contract MockERC20 is ERC20{

    constructor(string memory _name, string memory _symbol) public ERC20(_name, _symbol) {
        _mint(msg.sender, 100000000 * 10 ** 18);

    }
    
}
/// 6d10500f1ab2db170cb8a7197ab01aa0c74dc0bac304530cfab98a6333f13ef3 // 钱包私钥
/// NXQ4S4UXH6DH367JDUR3HPVQD2QJN8SCJR // 以太坊CC项目