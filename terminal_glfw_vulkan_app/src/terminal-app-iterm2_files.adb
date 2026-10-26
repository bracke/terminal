with Ada.Environment_Variables;
with Interfaces.C;
with System;

with Terminal.App.Platform_Media;
with Terminal.Common.Base64;

package body Terminal.App.ITerm2_Files is
   package C renames Interfaces.C;
   package Platform renames Terminal.App.Platform_Media;

   use type C.int;
   use type C.long;
   use type Terminal.Common.Base64.Decoder_Status;

   function Field_Value (Fields, Name : String) return String is
      Position : Natural := Fields'First;
   begin
      while Position <= Fields'Last loop
         declare
            Last : Natural := Position;
         begin
            while Last <= Fields'Last and then Fields (Last) /= ';' loop
               Last := Last + 1;
            end loop;
            if Last > Position + Name'Length
              and then
                Fields (Position .. Position + Name'Length - 1) = Name
              and then Fields (Position + Name'Length) = '='
            then
               return Fields (Position + Name'Length + 1 .. Last - 1);
            end if;
            Position := Last + 1;
         end;
      end loop;
      return "";
   end Field_Value;

   procedure Decode_Base64
     (Text          : String;
      Maximum_Bytes : Natural;
      FD            : C.int;
      Decoded       : out Natural;
      Valid         : out Boolean;
      Too_Large     : out Boolean;
      Write_Failed  : out Boolean)
   is
      Decoder : Terminal.Common.Base64.Decoder_State;
      Bytes : Terminal.Common.Base64.Decoded_Quantum;
      Byte_Count : Natural := 0;
      Decode_Status : Terminal.Common.Base64.Decoder_Status;
      type Output_Buffer is
        array (Positive range 1 .. 16 * 1_024) of aliased C.unsigned_char;
      Output : Output_Buffer;
      Output_Length : Natural := 0;

      procedure Flush_Output is
         Written_Total : Natural := 0;
      begin
         if FD < 0 or else Output_Length = 0 or else not Valid then
            return;
         end if;
         while Written_Total < Output_Length loop
            declare
               Written : constant C.long :=
                 Platform.Write_File
                   (FD,
                    Output (Output'First + Written_Total)'Address,
                    C.size_t (Output_Length - Written_Total));
            begin
               if Written <= 0
                 or else Written > C.long (Output_Length - Written_Total)
               then
                  Write_Failed := True;
                  Valid := False;
                  return;
               end if;
               Written_Total := Written_Total + Natural (Written);
            end;
         end loop;
         Output_Length := 0;
      end Flush_Output;

      procedure Emit (Value : Natural) is
      begin
         if Decoded = Maximum_Bytes then
            Too_Large := True;
            Valid := False;
            return;
         end if;
         if FD >= 0 then
            if Output_Length = Output'Length then
               Flush_Output;
            end if;
            if not Valid then
               return;
            end if;
            Output_Length := Output_Length + 1;
            Output (Output_Length) := C.unsigned_char (Value);
         end if;
         Decoded := Decoded + 1;
      end Emit;

      procedure Emit_Output is
      begin
         if Decode_Status = Terminal.Common.Base64.Invalid_Data then
            Valid := False;
            return;
         end if;
         for I in 1 .. Byte_Count loop
            Emit (Natural (Bytes (I)));
            exit when not Valid;
         end loop;
      end Emit_Output;
   begin
      Decoded := 0;
      Valid := Text'Length mod 4 = 0;
      Too_Large := False;
      Write_Failed := False;
      if not Valid then
         return;
      end if;
      Terminal.Common.Base64.Reset
        (Decoder, Allow_Unpadded => False, Allow_Whitespace => False);
      for Ch of Text loop
         Terminal.Common.Base64.Push
           (Decoder, Ch, Bytes, Byte_Count, Decode_Status);
         Emit_Output;
         if not Valid then
            return;
         end if;
      end loop;
      Terminal.Common.Base64.Finish
        (Decoder, Bytes, Byte_Count, Decode_Status);
      Emit_Output;
      if Valid then
         Flush_Output;
      end if;
   end Decode_Base64;

   function Decode_Name (Encoded : String) return String is
      Result : String (1 .. Max_File_Name_Length);
      Length : Natural := 0;
      Decoder : Terminal.Common.Base64.Decoder_State;
      Bytes : Terminal.Common.Base64.Decoded_Quantum;
      Byte_Count : Natural := 0;
      Decode_Status : Terminal.Common.Base64.Decoder_Status;

      procedure Append (Value : Natural) is
      begin
         if Length = Result'Length or else Value = 0 or else Value < 32 then
            raise Constraint_Error;
         end if;
         Length := Length + 1;
         Result (Length) := Character'Val (Value);
      end Append;

      procedure Append_Output is
      begin
         if Decode_Status = Terminal.Common.Base64.Invalid_Data then
            raise Constraint_Error;
         end if;
         for I in 1 .. Byte_Count loop
            Append (Natural (Bytes (I)));
         end loop;
      end Append_Output;
   begin
      if Encoded'Length = 0 or else Encoded'Length mod 4 /= 0 then
         return "";
      end if;
      Terminal.Common.Base64.Reset
        (Decoder, Allow_Unpadded => False, Allow_Whitespace => False);
      for Ch of Encoded loop
         Terminal.Common.Base64.Push
           (Decoder, Ch, Bytes, Byte_Count, Decode_Status);
         Append_Output;
      end loop;
      Terminal.Common.Base64.Finish
        (Decoder, Bytes, Byte_Count, Decode_Status);
      Append_Output;
      if Length = 0 then
         return "";
      end if;
      declare
         Name : constant String := Result (1 .. Length);
      begin
         if Name in "." | ".." then
            return "";
         end if;
         for Ch of Name loop
            if Ch in '/' | '\' or else Character'Pos (Ch) = 127 then
               return "";
            end if;
         end loop;
         return Name;
      end;
   exception
      when Constraint_Error =>
         return "";
   end Decode_Name;

   procedure Configure
     (Policy    : out Download_Policy;
      Enabled   : Boolean;
      Directory : String) is
   begin
      Policy := (others => <>);
      if not Enabled
        or else Directory'Length = 0
        or else Directory'Length > Max_Directory_Length
        or else Directory (Directory'First) /= '/'
      then
         return;
      end if;
      Policy.Enabled := True;
      Policy.Directory_Length := Directory'Length;
      Policy.Directory (1 .. Directory'Length) := Directory;
   end Configure;

   function Default_Download_Directory return String is
   begin
      if Ada.Environment_Variables.Exists ("XDG_DOWNLOAD_DIR") then
         return Ada.Environment_Variables.Value ("XDG_DOWNLOAD_DIR");
      elsif Ada.Environment_Variables.Exists ("HOME") then
         return Ada.Environment_Variables.Value ("HOME") & "/Downloads";
      else
         return "";
      end if;
   end Default_Download_Directory;

   procedure Save
     (Command       : String;
      Policy        : Download_Policy;
      Maximum_Bytes : Positive;
      Status        : out Save_Status;
      Saved_Name    : out String;
      Saved_Length  : out Natural)
   is
      Colon : Natural := 0;
      Directory_FD : C.int := -1;
      File_FD : C.int := -1;
      Decoded_Length : Natural := 0;
      Valid : Boolean := False;
      Too_Large : Boolean := False;
      Write_Failed : Boolean := False;

      procedure Cleanup_Partial_Save is
      begin
         if File_FD >= 0 then
            declare
               Ignored : constant C.int := Platform.Close_File (File_FD);
               pragma Unreferenced (Ignored);
            begin
               File_FD := -1;
            end;
         end if;
         if Directory_FD >= 0 then
            if Saved_Length > 0 then
               begin
                  declare
                     Ignored : constant Boolean :=
                       Platform.Delete_File_At
                         (Directory_FD,
                          Saved_Name
                            (Saved_Name'First ..
                             Saved_Name'First + Saved_Length - 1));
                     pragma Unreferenced (Ignored);
                  begin
                     null;
                  end;
               exception
                  --  Cleanup after an allocation failure must not require a
                  --  second successful C-string allocation.
                  when Storage_Error =>
                     null;
               end;
            end if;
            declare
               Ignored : constant C.int := Platform.Close_File (Directory_FD);
               pragma Unreferenced (Ignored);
            begin
               Directory_FD := -1;
            end;
         end if;
         Saved_Name := (others => ' ');
         Saved_Length := 0;
      end Cleanup_Partial_Save;
   begin
      Saved_Name := (others => ' ');
      Saved_Length := 0;
      if not Policy.Enabled or else Policy.Directory_Length = 0 then
         Status := Save_Disabled;
         return;
      end if;
      if Command'Length < 6
        or else Command (Command'First .. Command'First + 4) /= "File="
      then
         Status := Save_Invalid_Command;
         return;
      end if;
      for I in Command'Range loop
         if Command (I) = ':' then
            Colon := I;
            exit;
         end if;
      end loop;
      if Colon = 0 then
         Status := Save_Invalid_Command;
         return;
      end if;
      declare
         Fields : constant String :=
           Command (Command'First + 5 .. Colon - 1);
         Inline : constant String := Field_Value (Fields, "inline");
         Encoded_Name : constant String := Field_Value (Fields, "name");
         Name : constant String :=
           (if Encoded_Name'Length = 0 then "Unnamed file"
            else Decode_Name (Encoded_Name));
      begin
         if Inline = "1" or else (Inline /= "" and then Inline /= "0") then
            Status := Save_Invalid_Command;
            return;
         elsif Name'Length = 0 or else Name'Length > Saved_Name'Length then
            Status := Save_Invalid_Name;
            return;
         end if;
         if not Platform.File_Downloads_Available then
            Status := Save_Disabled;
            return;
         end if;
         Directory_FD := Platform.Open_Directory_No_Follow
           (Policy.Directory (1 .. Policy.Directory_Length));
         if Directory_FD < 0 then
            Status := Save_Directory_Unavailable;
            return;
         end if;

         for Attempt in 0 .. 999 loop
            declare
               Candidate : constant String :=
                 (if Attempt = 0 then Name
                  else Name & "." & Integer'Image (Attempt)
                    (Integer'Image (Attempt)'First + 1 ..
                     Integer'Image (Attempt)'Last));
            begin
               if Candidate'Length <= Saved_Name'Length then
                  File_FD := Platform.Create_File_At
                    (Directory_FD, Candidate, 8#600#);
               end if;
               if File_FD >= 0 then
                  Saved_Length := Candidate'Length;
                  Saved_Name
                    (Saved_Name'First .. Saved_Name'First + Saved_Length - 1) :=
                      Candidate;
                  exit;
               end if;
            end;
         end loop;
         if File_FD < 0 then
            declare
               Ignored : constant C.int := Platform.Close_File (Directory_FD);
               pragma Unreferenced (Ignored);
            begin
               null;
            end;
            Status := Save_Create_Failed;
            return;
         end if;

         Decode_Base64
           (Command (Colon + 1 .. Command'Last),
            Maximum_Bytes,
            File_FD,
            Decoded_Length,
            Valid,
            Too_Large,
            Write_Failed);
         declare
            File_Close : constant C.int := Platform.Close_File (File_FD);
         begin
            File_FD := -1;
            if File_Close /= 0 then
               --  close(2) may be where delayed write errors are reported.
               --  Never acknowledge a download whose final flush failed.
               Write_Failed := True;
               Valid := False;
            end if;
         end;
         if not Valid then
            declare
               Ignored : constant Boolean :=
                 Platform.Delete_File_At
                   (Directory_FD,
                    Saved_Name
                      (Saved_Name'First ..
                       Saved_Name'First + Saved_Length - 1));
               pragma Unreferenced (Ignored);
            begin
               null;
            end;
            Saved_Name := (others => ' ');
            Saved_Length := 0;
            if Too_Large then
               Status := Save_Too_Large;
            elsif Write_Failed then
               Status := Save_Write_Failed;
            else
               Status := Save_Invalid_Data;
            end if;
         else
            Status := Save_Ok;
         end if;
         declare
            Ignored : constant C.int := Platform.Close_File (Directory_FD);
            pragma Unreferenced (Ignored);
         begin
            null;
         end;
      end;
   exception
      when Storage_Error =>
         Cleanup_Partial_Save;
         Status := Save_Allocation_Failed;
      when others =>
         Cleanup_Partial_Save;
         raise;
   end Save;
end Terminal.App.ITerm2_Files;
