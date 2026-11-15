with Terminal.Core.Graphics_Runtime;

separate (Terminal.Core)
procedure Process_Kitty_Graphics_APC
  (T       : in out Terminal;
   Payload : String)
is
   Control : constant Kitty_Chunk_Control :=
     Parse_Kitty_Chunk_Control
       (Payload,
        Continuation => T.Graphics.Kitty_Chunk_Active,
        Initial_Action => T.Graphics.Kitty_Chunk_Action);
   Data_Length : constant Natural :=
     (if Control.Data_First = 0
        or else Control.Data_First > Payload'Last
      then 0
      else Payload'Last - Control.Data_First + 1);

   procedure Queue_Current
     (Text       : String;
      Invalid    : Boolean := False) is
   begin
      Note_Graphics_Protocol
        (T,
         Graphics_Kitty,
         Text'Length,
         Text,
         Kitty_Validation_Error => Invalid);
   end Queue_Current;

   procedure Queue_Partial_Error is
   begin
      if T.Graphics.Kitty_Chunk_Data /= null and then T.Graphics.Kitty_Chunk_Length > 0 then
         Queue_Current
           (T.Graphics.Kitty_Chunk_Data (1 .. T.Graphics.Kitty_Chunk_Length),
            Invalid => True);
      else
         Queue_Current (Payload, Invalid => True);
      end if;
      Graphics_Runtime.Advance_Graphics_Transaction (T.Graphics);
      Graphics_Runtime.Clear_Kitty_Chunk (T.Graphics);
   end Queue_Partial_Error;
begin
   if not T.Graphics.Kitty_Chunk_Active then
      if Control.Valid and then Control.More_Specified and then Control.More
      then
         if Control.Transmission in 'f' | 't' | 's'
           or else Data_Length > 4_096
           or else Data_Length mod 4 /= 0
         then
            Queue_Current (Payload, Invalid => True);
            return;
         end if;

         if Control.Data_First = 0 then
            --  Some real clients (notably Chafa) send a metadata-only
            --  first chunk and begin the base64 data in the next APC.
            --  Preserve the separator needed by the assembled command.
            declare
               Normalized : String := Payload & ";";
            begin
               Normalized (Control.More_Value_Index) := '0';
               if not Graphics_Runtime.Append_Kitty_Chunk_Data
                 (T.Graphics, Normalized)
               then
                  Queue_Current (Payload, Invalid => True);
                  Graphics_Runtime.Clear_Kitty_Chunk (T.Graphics);
                  return;
               end if;
            end;
         else
            declare
               Normalized : String := Payload;
            begin
               Normalized (Control.More_Value_Index) := '0';
               if not Graphics_Runtime.Append_Kitty_Chunk_Data
                 (T.Graphics, Normalized)
               then
                  Queue_Current (Payload, Invalid => True);
                  Graphics_Runtime.Clear_Kitty_Chunk (T.Graphics);
                  return;
               end if;
            end;
         end if;
         T.Graphics.Kitty_Chunk_Active := True;
         T.Graphics.Kitty_Chunk_Action := Control.Action;
         T.Graphics.Kitty_Chunk_Blocks_Input :=
           (not Control.Quiet_Specified or else Control.Quiet /= 2)
           or else
             (Control.Action in 'T' | 'p'
              and then Graphics_Runtime.Kitty_Field_Value (Payload, 'C') /= "1"
              and then Graphics_Runtime.Kitty_Field_Value (Payload, 'U') /= "1"
              and then
                (Graphics_Runtime.Kitty_Field_Value (Payload, 'P')'Length = 0
                 or else Graphics_Runtime.Kitty_Field_Value
                   (Payload, 'P') = "0"));
         return;
      end if;

      Queue_Current
        (Payload,
         Invalid =>
           (Control.More_Specified and then not Control.Valid));
      return;
   end if;

   --  A delete command is explicitly allowed to cancel a partial upload.
   if not Control.Valid
     and then Graphics_Runtime.Kitty_Field_Value (Payload, 'a') = "d"
     and then Data_Length = 0
   then
      Graphics_Runtime.Advance_Graphics_Transaction (T.Graphics);
      Graphics_Runtime.Clear_Kitty_Chunk (T.Graphics);
      Queue_Current (Payload);
      return;
   end if;

   if not Control.Valid
     or else Data_Length > 4_096
     or else (Control.More and then Data_Length mod 4 /= 0)
   then
      Queue_Partial_Error;
      return;
   end if;

   if Data_Length > 0
     and then not Graphics_Runtime.Append_Kitty_Chunk_Data
       (T.Graphics, Payload (Control.Data_First .. Payload'Last))
   then
      Queue_Partial_Error;
      return;
   end if;

   if Control.Quiet_Specified then
      if not Graphics_Runtime.Apply_Kitty_Chunk_Quiet
        (T.Graphics, Control.Quiet)
      then
         Queue_Partial_Error;
         return;
      end if;
      T.Graphics.Kitty_Chunk_Blocks_Input :=
        Control.Quiet /= 2
        or else
          (T.Graphics.Kitty_Chunk_Action in 'T' | 'p'
           and then
             Graphics_Runtime.Kitty_Field_Value
               (T.Graphics.Kitty_Chunk_Data (1 .. T.Graphics.Kitty_Chunk_Length), 'C') /= "1"
           and then
             Graphics_Runtime.Kitty_Field_Value
               (T.Graphics.Kitty_Chunk_Data (1 .. T.Graphics.Kitty_Chunk_Length), 'U') /= "1"
           and then
             (Graphics_Runtime.Kitty_Field_Value
                (T.Graphics.Kitty_Chunk_Data (1 .. T.Graphics.Kitty_Chunk_Length), 'P')'Length = 0
              or else Graphics_Runtime.Kitty_Field_Value
                (T.Graphics.Kitty_Chunk_Data (1 .. T.Graphics.Kitty_Chunk_Length), 'P') = "0"));
   end if;

   if Control.More then
      return;
   end if;

   Queue_Current
     (T.Graphics.Kitty_Chunk_Data (1 .. T.Graphics.Kitty_Chunk_Length));
   Graphics_Runtime.Clear_Kitty_Chunk (T.Graphics);
end Process_Kitty_Graphics_APC;
