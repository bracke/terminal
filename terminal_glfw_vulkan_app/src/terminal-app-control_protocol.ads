package Terminal.App.Control_Protocol is
   Max_Request_Length : constant := 4_096;
   Max_Payload_Length : constant := 4_000;

   type Command_Kind is
     (Invalid_Command,
      Ping,
      List_Sessions,
      Activate_Session,
      New_Tab,
      Close_Session,
      Split_Horizontal,
      Split_Vertical,
      Send_Text,
      Set_Title,
      Set_Theme,
      Reload_Config,
      Get_Text,
      Set_Read_Only,
      Set_Protected_Input,
      Show_Window,
      Hide_Window,
      Toggle_Window,
      Quit);

   type Parse_Status is
     (Parsed,
      Empty_Request,
      Request_Too_Long,
      Unknown_Command,
      Missing_Argument,
      Invalid_Argument,
      Payload_Too_Long,
      Control_Character);

   type Request is private;

   procedure Parse
     (Text   : String;
      Value  : out Request;
      Status : out Parse_Status);

   function Kind (Value : Request) return Command_Kind;
   function Index (Value : Request) return Positive;
   function Payload (Value : Request) return String;
   function Enabled (Value : Request) return Boolean;
   function Status_Label (Status : Parse_Status) return String;

private
   subtype Payload_Index is Positive range 1 .. Max_Payload_Length;
   type Request is record
      Command : Command_Kind := Invalid_Command;
      Number  : Positive := 1;
      Flag    : Boolean := False;
      Length  : Natural range 0 .. Max_Payload_Length := 0;
      Text    : String (Payload_Index) := (others => ' ');
   end record;
end Terminal.App.Control_Protocol;
