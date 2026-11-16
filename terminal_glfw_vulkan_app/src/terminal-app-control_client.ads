package Terminal.App.Control_Client is
   type Client_Status is
     (Ok,
      Invalid_Path,
      Request_Too_Long,
      Connect_Failed,
      Send_Failed,
      Response_Too_Long,
      Receive_Failed);

   procedure Execute
     (Path     : String;
      Request  : String;
      Response : out String;
      Length   : out Natural;
      Status   : out Client_Status);

   function Status_Label (Status : Client_Status) return String;
end Terminal.App.Control_Client;
