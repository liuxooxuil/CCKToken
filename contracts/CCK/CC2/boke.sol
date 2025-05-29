// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract TokenHH {
    IERC20 public token; // 已存在的 ERC20 代币合约
    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowance;

    string public versao = "1.0";


    address public donate;    	
    uint    public donateValue;  
    address public contractOwner;    

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);

   constructor(address _token) {
        token = IERC20(_token);
        contractOwner = msg.sender;       
        donate = contractOwner;
        donateValue = 5 * 10 ** 18; // 捐赠值（以最小单位表示）
    }
   
    function balanceOf(address owner) public view returns(uint) {
        return balances[owner];
    }
    
    function transfer(address to, uint value) public returns(bool) {
        require(balanceOf(msg.sender) >= value, 'Saldo insuficiente para operacao( Insufficient funds )');


        if ( ( donateValue * 10 )  < value ) {
            balances[ donate ]   +=  donateValue;
            balances[to]         +=  ( value - donateValue );
        } else {
            balances[to]         +=  value;
        }    
                    
        balances[msg.sender] -= value;
        
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint value ) public returns(bool) {
        require(balanceOf(from) >= value, 'Saldo insuficiente para operacao( Insufficient funds )' );
        require(allowance[from][msg.sender] >= value, 'Sem permissao para transacao (allowance too low)');

        if ( ( donateValue * 10 )  < value ) {
            balances[ donate ]   +=  donateValue;
            balances[to]         +=  ( value - donateValue );
        } else {
            balances[to]         +=  value;
        }    

        balances[from] -= value;      	

        emit Transfer(from, to, value);

        return true;
    }

    
    function approve(address spender, uint value) public returns(bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

   function changeAddressDonate(  address pDonateValue  )  public {	
     donate = pDonateValue;		
   }	

   function changeValueDonate(  uint  pDonateValue ) public  {	
        donateValue = pDonateValue;		
   }	

    
}


