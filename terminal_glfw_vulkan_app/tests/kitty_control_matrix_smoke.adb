with AUnit.Assertions;
with Ada.Strings;
with Ada.Strings.Fixed;

with Terminal.App.Graphics;
with Terminal.Core;

procedure Kitty_Control_Matrix_Smoke is
   use AUnit.Assertions;
   use type Terminal.Core.Graphics_ID;

   subtype Action_Index is Positive range 1 .. 8;
   Actions : constant array (Action_Index) of Character :=
     ['t', 'T', 'q', 'p', 'd', 'f', 'a', 'c'];

   function Header
     (Text : String) return Terminal.App.Graphics.Graphics_Header
   is
     (Terminal.App.Graphics.Header_Text
        (Terminal.Core.Kitty_Graphics, Text));

   function Image (Value : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Both));

   procedure Assert_Valid (Text, Label_Text : String) is
      Value : constant Terminal.App.Graphics.Graphics_Header := Header (Text);
   begin
      Assert (Value.Recognized, Label_Text & " recognized");
      Assert
        (Value.Kitty_Control_Data_Valid,
         Label_Text & " control syntax");
      Assert
        (Value.Kitty_Transmission_Valid
         and then Value.Kitty_Compression_Valid
         and then Value.Kitty_More_Valid
         and then Value.Kitty_Data_Size_Valid
         and then Value.Kitty_Data_Offset_Valid
         and then Value.Kitty_Geometry_Controls_Valid,
         Label_Text & " control values");
      Assert
        (Value.Kitty_Action_Controls_Valid,
         Label_Text & " action controls");
   end Assert_Valid;

   function Action_Command (Action : Character) return String is
   begin
      case Action is
         when 't' | 'T' =>
            return "Ga=" & Action & ",f=32,i=1,s=1,v=1;/wAA/w==";
         when 'q' =>
            return "Ga=q,f=32,i=1,s=1,v=1;/wAA/w==";
         when 'p' =>
            return "Ga=p,i=1";
         when 'd' =>
            return "Ga=d,d=a";
         when 'f' =>
            return "Ga=f,f=32,i=1,s=1,v=1;/wAA/w==";
         when 'a' =>
            return "Ga=a,i=1,s=1";
         when 'c' =>
            return "Ga=c,i=1,c=1,r=1";
         when others =>
            raise Program_Error;
      end case;
   end Action_Command;

   function Delete_Parameters (Selector : Character) return String is
   begin
      case Selector is
         when 'i' | 'I' | 'f' | 'F' =>
            return ",i=17";
         when 'n' | 'N' =>
            return ",I=18";
         when 'p' | 'P' | 'q' | 'Q' =>
            return ",x=2,y=3";
         when 'x' | 'X' =>
            return ",x=2";
         when 'y' | 'Y' =>
            return ",y=3";
         when 'r' | 'R' =>
            return ",x=17,y=19";
         when 'z' | 'Z' =>
            return ",z=-2";
         when others =>
            return "";
      end case;
   end Delete_Parameters;

   Delete_Selectors : constant String := "aAcCnNiIfFpPqQrRxXyYzZ";
   Transmission_Values : constant String := "dfts";
   Format_Values : constant array (Positive range 1 .. 5) of Natural :=
     [8, 16, 24, 32, 100];

   function Invalid_Command (Index : Positive) return String is
   begin
      case Index is
         when 1 => return "Ga=x,i=1";
         when 2 => return "Ga=p,i=1;AAAA";
         when 3 => return "Ga=q,i=1";
         when 4 => return "Ga=d,d=p,x=1";
         when 5 => return "Ga=f,i=1,X=2;AAAA";
         when 6 => return "Ga=a,i=1,s=4";
         when 7 => return "Ga=c,i=1,c=0,r=1";
         when 8 => return "Ga=t,i=1,I=2;AAAA";
         when others => raise Program_Error;
      end case;
   end Invalid_Command;
begin
   --  Every action has an independently valid minimal command.  This catches
   --  accidental omissions when the action dispatch or validation table is
   --  extended.
   for Index in Actions'Range loop
      declare
         Action : constant Character := Actions (Index);
         Value : constant Terminal.App.Graphics.Graphics_Header :=
           Header (Action_Command (Action));
      begin
         Assert_Valid (Action_Command (Action), "action " & Action);
         Assert (Value.Kitty_Action = Action, "action identity " & Action);
      end;
   end loop;

   --  Transmission controls: a,f,t,s,v,S,O,i,p,o,m,N,q.  Image-number
   --  addressing is checked separately because i and I are mutually
   --  exclusive by specification.
   declare
      Value : constant Terminal.App.Graphics.Graphics_Header := Header
        ("Ga=t,f=24,t=f,s=2,v=3,S=4,O=5,i=6,p=7,o=z,m=1,N=8,q=2;AAAA");
   begin
      Assert_Valid
        ("Ga=t,f=24,t=f,s=2,v=3,S=4,O=5,i=6,p=7,o=z,m=1,N=8,q=2;AAAA",
         "transmission control matrix");
      Assert
        (Value.Kitty_Action = 't'
         and then Value.Kitty_Format = 24
         and then Value.Kitty_Transmission = 'f'
         and then Value.Pixel_Width = 2
         and then Value.Pixel_Height = 3
         and then Value.Kitty_Data_Size = 4
         and then Value.Kitty_Data_Offset = 5
         and then Value.Kitty_ID = 6
         and then Value.Kitty_Placement_ID = 7
         and then Value.Kitty_Compression = 'z'
         and then Value.Kitty_More
         and then Value.Kitty_Usage_Hint = 8
         and then Value.Kitty_Quiet = 2,
         "transmission control values");
   end;
   declare
      Value : constant Terminal.App.Graphics.Graphics_Header :=
        Header ("Ga=t,I=9,f=32,s=1,v=1;AAAA");
   begin
      Assert_Valid
        ("Ga=t,I=9,f=32,s=1,v=1;AAAA", "image number control");
      Assert (Value.Kitty_Image_Number = 9, "image number value");
   end;

   --  Display controls: x,y,w,h,X,Y,c,r,C,U,z,P,Q,H,V.
   declare
      Text : constant String :=
        "Ga=T,f=32,i=6,p=7,s=1,v=1,x=2,y=3,w=4,h=5,"
        & "X=6,Y=7,c=8,r=9,C=1,U=1,z=-10,P=11,Q=12,H=-13,V=14;AAAA";
      Value : constant Terminal.App.Graphics.Graphics_Header := Header (Text);
   begin
      Assert_Valid (Text, "display control matrix");
      Assert
        (Value.Kitty_Source_X = 2
         and then Value.Kitty_Source_Y = 3
         and then Value.Kitty_Source_Width = 4
         and then Value.Kitty_Source_Height = 5
         and then Value.Kitty_Cell_X = 6
         and then Value.Kitty_Cell_Y = 7
         and then Value.Placeholder_Cols = 8
         and then Value.Placeholder_Rows = 9
         and then Value.Kitty_No_Cursor_Move
         and then Value.Kitty_Virtual_Placement
         and then Value.Kitty_Z_Index = -10
         and then Value.Kitty_Parent_ID = 11
         and then Value.Kitty_Parent_Placement_ID = 12
         and then Value.Kitty_Parent_Offset_X = -13
         and then Value.Kitty_Parent_Offset_Y = 14,
         "display control values");
   end;

   --  The reused keys below have action-specific meanings.  Exercise every
   --  documented frame-load, frame-composition, and animation control in its
   --  own action domain instead of relying on the display interpretation.
   declare
      Text : constant String :=
        "Ga=f,f=32,i=6,s=1,v=1,r=2,c=1,z=-3,X=1,Y=4;AAAA";
      Value : constant Terminal.App.Graphics.Graphics_Header := Header (Text);
   begin
      Assert_Valid (Text, "frame-load control matrix");
      Assert
        (Value.Kitty_Frame_Number = 2
         and then Value.Kitty_Base_Frame = 1
         and then Value.Kitty_Frame_Gap = -3
         and then Value.Kitty_Composition_Mode = 1
         and then Value.Kitty_Background_Color = 4,
         "frame-load control values");
   end;
   declare
      Text : constant String :=
        "Ga=c,i=6,c=2,r=1,x=3,y=4,w=5,h=6,X=7,Y=8,C=1";
      Value : constant Terminal.App.Graphics.Graphics_Header := Header (Text);
   begin
      Assert_Valid (Text, "frame-composition control matrix");
      Assert
        (Value.Kitty_Frame_Number = 2
         and then Value.Kitty_Base_Frame = 1
         and then Value.Kitty_Source_X = 3
         and then Value.Kitty_Source_Y = 4
         and then Value.Kitty_Source_Width = 5
         and then Value.Kitty_Source_Height = 6
         and then Value.Kitty_Cell_X = 7
         and then Value.Kitty_Cell_Y = 8
         and then Value.Kitty_Composition_Mode = 1,
         "frame-composition control values");
   end;
   declare
      Text : constant String := "Ga=a,i=6,s=3,r=2,c=1,z=-4,v=5";
      Value : constant Terminal.App.Graphics.Graphics_Header := Header (Text);
   begin
      Assert_Valid (Text, "animation control matrix");
      Assert
        (Value.Kitty_Animation_State = 3
         and then Value.Kitty_Frame_Number = 2
         and then Value.Kitty_Base_Frame = 1
         and then Value.Kitty_Frame_Gap = -4
         and then Value.Kitty_Loop_Count = 5,
         "animation control values");
   end;

   --  Enumerated value domains that are easy to lose when validation is
   --  tightened.  The format loop includes the indexed extensions supported
   --  by this backend in addition to Kitty's RGB/RGBA/PNG formats.
   for Transmission of Transmission_Values loop
      Assert_Valid
        ("Ga=t,t=" & Transmission & ",f=32,i=1,s=1,v=1;AAAA",
         "transmission medium " & Transmission);
   end loop;
   for Format of Format_Values loop
      Assert_Valid
        ("Ga=t,f=" & Image (Format) & ",i=1,s=1,v=1;AAAA",
         "format " & Image (Format));
   end loop;
   for Quiet in 0 .. 2 loop
      Assert_Valid
        ("Ga=t,q=" & Image (Quiet) & ",i=1,s=1,v=1;AAAA",
         "quiet " & Image (Quiet));
   end loop;
   for More in 0 .. 1 loop
      Assert_Valid
        ("Ga=t,m=" & Image (More) & ",i=1,s=1,v=1;AAAA",
         "chunk flag " & Image (More));
   end loop;
   for State in 1 .. 3 loop
      Assert_Valid
        ("Ga=a,i=1,s=" & Image (State),
         "animation state " & Image (State));
   end loop;
   for Mode in 0 .. 1 loop
      Assert_Valid
        ("Ga=c,i=1,c=1,r=1,C=" & Image (Mode),
         "composition mode " & Image (Mode));
   end loop;

   --  All 24 deletion selectors are generated from one authoritative list.
   --  Both cases are significant: uppercase variants also remove image data.
   for Selector of Delete_Selectors loop
      declare
         Text : constant String :=
           "Ga=d,d=" & Selector & Delete_Parameters (Selector);
         Value : constant Terminal.App.Graphics.Graphics_Header := Header (Text);
      begin
         Assert_Valid (Text, "delete selector " & Selector);
         Assert
           (Value.Kitty_Delete = Selector
            and then Value.Kitty_Delete_Controls_Valid,
            "delete selector identity " & Selector);
      end;
   end loop;

   --  Negative rows make the validity matrix executable rather than merely
   --  an inventory of accepted examples.
   for Index in 1 .. 8 loop
      declare
         Text : constant String := Invalid_Command (Index);
         Value : constant Terminal.App.Graphics.Graphics_Header := Header (Text);
      begin
         Assert
           (Value.Recognized and then not Value.Kitty_Action_Controls_Valid,
            "invalid action/control combination rejected: " & Text);
      end;
   end loop;
end Kitty_Control_Matrix_Smoke;
