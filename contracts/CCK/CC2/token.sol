// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;
// import "openzeppelin-solidity/contracts/math/SafeMath.sol";

// contract Token {
//     using SafeMath for uint256;
//     string public name = "navneet";
//     string public symbol = "DApp";
//     uint256 public decimal = 18;
//     uint256 public totalSupply;

//     //track balance
//     mapping(address => uint256) public balanceOf;
//     mapping(address => mapping(address => uint256)) public allowance;
//     event Transfer(address indexed from, address indexed to, uint256 value);
//     event Approval(address indexed owner, address indexed spender, uint256 value);

//     constructor() public {
//         totalSupply = 1000000 * (10 ** 18);
//         balanceOf[msg.sender] = totalSupply;
//     }

//     function transfer(
//         address _to,
//         uint256 _value
//     ) public returns (bool success) {
//         require(_to != address(0));
//         require(balanceOf[msg.sender] >= _value);

//         balanceOf[msg.sender] = balanceOf[msg.sender].sub(_value);
//         balanceOf[_to] = balanceOf[_to].add(_value);
//         emit Transfer(msg.sender, _to, _value);
//         return true;
//     }

//     function approve(
//         address _spender,
//         uint256 _value
//     ) public returns (bool success) {
//         require(_spender != address(0));
//         allowance[msg.sender][_spender] = _value;
       
//         emit Approval(msg.sender,_spender,_value);
//          return true;
//     }

//     function _transfer(address _from, address _to, uint256 _value) internal {
//         require(_to != address(0));
//         balanceOf[_from] = balanceOf[_from].sub(_value);
//         balanceOf[_to] = balanceOf[_to].add(_value);
//         emit Transfer(_from, _to, _value);
//         // return true;
//     }

//     function transferfrom(
//         address _from,
//         address _to,
//         uint256 _value
//     ) public returns (bool success) {
//         require(_value<=balanceOf[_from]);
//         require(_value<=allowance[_from][msg.sender]);
//         // allowance[_from][msg.sender] = allowance[_from][_spender].sub(
//         //     _value
//         // );
//         allowance[_from][msg.sender]=allowance[_from][msg.sender].sub(_value);
//         _transfer(_from, _to, _value);
//         return true;
//         // emit Approve;
//     }
// }