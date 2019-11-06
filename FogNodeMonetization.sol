pragma solidity >=0.4.22 <0.6.0;
contract Monetization{
    struct fog_type{
        bool exists;
        uint rate;
        mapping(address=>bool)subsribed_clients;
        mapping(address=>bool)connected_clients;
    }
    
    mapping (address => fog_type) public fog_nodes;
    
    struct client_type{
      uint deposit;
      address connected_fognode;
      bool exists;
      uint timeLeft;
      bytes32 access_token;
      uint amount_due;
    }
    
    mapping (address => client_type) public clients;
    
    event FogNodeRegistered(address fogAddress, uint rate);
    
    event ClientRegistered(address clientAddress);
    
    event AmountDeposited(address clientAddress, uint amount);
    
    event Subscribed(address clientAddress, address fogAddress);
    
    event Connected(address clientAddress,address fogAddress,bytes32 accessToken);
    
    event ConnectionTerminated(address clientAddress,address fogAddress);
    
    event ClientBlocked(address clientAddress);
    
    event AmountRefunded(address clientAddress, uint amount);
    
    address payable public owner;
    
    modifier onlyOwner{
      require(msg.sender == owner);
      _;
    }
    
    modifier onlyClient{
      require(clients[msg.sender].exists);
      _;
    }
    
    modifier onlyFog{
      require(fog_nodes[msg.sender].exists);
      _;
    }
    
    constructor () public{
        owner = msg.sender;
    }
    
    function regfog(address fog_node, uint rate) onlyOwner public{
        require(!fog_nodes[fog_node].exists);
        fog_type memory f;
        f.exists=true;
        f.rate=rate;
        fog_nodes[fog_node]=(f);
        emit FogNodeRegistered(fog_node,rate);
    }
    
    function regclient() payable onlyClient public{
        require(!clients[msg.sender].exists);
        clients[msg.sender]=(client_type(msg.value,address(0),true,0,0,0));
        emit ClientRegistered(msg.sender);
    }
    
    function deposit() payable onlyClient public{
        clients[msg.sender].deposit += msg.value;
        emit AmountDeposited(msg.sender,msg.value);
    }
    
    function getDeposit() public onlyClient view returns(uint){
        return clients[msg.sender].deposit;
    }
    
    function getDueAmount(address client) onlyClient view public returns(uint){
        return clients[client].amount_due;
    }
    
    function subscribe(address fog_node) onlyClient public{
        require(getDueAmount(msg.sender)==0);
        fog_nodes[fog_node].subsribed_clients[msg.sender]=true;
        emit Subscribed(msg.sender, fog_node);
    }
    
    function connect(address fog_node) payable onlyClient public{
        require(fog_nodes[fog_node].exists && clients[msg.sender].exists && getDeposit()>=getFograte(fog_node) && getDueAmount(msg.sender)==0);
        if(!fog_nodes[fog_node].subsribed_clients[msg.sender]){
            subscribe(fog_node);
        }
        fog_nodes[fog_node].connected_clients[msg.sender]=true;
        clients[msg.sender].connected_fognode=fog_node;
        clients[msg.sender].timeLeft = getDeposit()/getFograte(fog_node);
        uint randomVal = block.timestamp;
        clients[msg.sender].access_token = keccak256(abi.encodePacked(msg.sender,randomVal,owner));
        emit Connected(msg.sender,fog_node,clients[msg.sender].access_token);
    }
    
    function isconnected(address fog_node, address client) public view returns(bool){
        return fog_nodes[fog_node].connected_clients[client];
    }
    
    function disconnect(address fog_node,address client) onlyClient public{
        require(fog_nodes[fog_node].exists && clients[client].exists);
        fog_nodes[fog_node].connected_clients[client]=false;
        clients[client].connected_fognode=address(0);
        clients[client].access_token=0;
    }
    
    function getFograte(address fog_node) private view returns (uint){
        return fog_nodes[fog_node].rate;
    }
    
    function getRemainingTime(address client) view public returns (uint){
        return clients[client].timeLeft;
    }
    
    function getConnectedFogNode(address client) view public returns (address){
        return clients[client].connected_fognode;
    }
    
    function endConnection(address fog_node, address client,uint time) public {
        uint amount = time * getFograte(fog_node);
        if(clients[client].deposit>amount)
        {
            clients[client].amount_due=amount-clients[client].deposit;
            emit ClientBlocked(client);
        }
        clients[client].deposit-=amount;
        owner.transfer(amount);
        disconnect(fog_node,client);
        emit ConnectionTerminated(client,fog_node);
    }
    
    function refundBalance() public{
        require(clients[msg.sender].connected_fognode == address(0) && getDueAmount(msg.sender)==0);
        msg.sender.transfer(getDeposit());
        emit AmountRefunded(msg.sender,getDeposit());
        disconnect(getConnectedFogNode(msg.sender),msg.sender);
        clients[msg.sender]=(client_type(0,address(0),true,0,0,0));
    }

}
