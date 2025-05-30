// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // ERC20 标准
contract MockERC20 is ERC20{

    constructor(string memory _name, string memory _symbol) public ERC20(_name, _symbol) {
        _mint(msg.sender, 100000000 * 10 ** 18);

    }
    
}

contract Test{
    ERC20 erc20;
    constructor(ERC20 _erc20) public{
        erc20 = _erc20;
    }
    function transferFrom(address _to,uint256 _amount) public{
        erc20.transferFrom(msg.sender,_to,_amount);
    }
}

contract Test1{
    address erc20;
    constructor(address _erc20) public{
        erc20 = _erc20;
    }
    function transferFrom(address _to,uint256 _amount) public returns(bool){
      bytes32 a =  keccak256("transferFrom(address,address,uint256)");
      bytes4 methodId = bytes4(a);
      bytes memory b =  abi.encodeWithSelector(methodId,msg.sender,_to,_amount);
      (bool result,) = erc20.call(b);
      return result;
    }
}

