separate (Terminal.App.Image_Store)
procedure Adopt_Frames
  (Container : in out Store;
   Object    : Image_Object_Access;
   Head      : in out Image_Frame_Access)
is
   Slow : Image_Frame_Access := Head;
   Fast : Image_Frame_Access := Head;
   Current : Image_Frame_Access := Head;
   Tail : Image_Frame_Access := null;
   Count : Natural := 0;
   Bytes : Natural := 0;
   Seen : Address_Sets.Set;

   procedure Register (Data : Terminal.App.Render_Model.Image_Data_Access) is
      Address : System.Address;
   begin
      if Data = null then
         return;
      end if;
      Address := Data.all'Address;
      if Seen.Contains (Address) then
         raise Program_Error with "image frames share owned storage";
      end if;
      Seen.Insert (Address);
   end Register;
begin
   if not Is_Owned (Container, Object) then
      raise Program_Error with "image object is not owned by this store";
   elsif Object.Frames /= null then
      raise Program_Error with "image object already has animation frames";
   end if;
   Register (Object.Bytes);
   Register (Object.Indexed_Bytes);
   declare
      Operation : Theme_Operation_Access := Object.Theme_Operations;
   begin
      while Operation /= null loop
         Register (Operation.Bytes);
         Operation := Operation.Next;
      end loop;
   end;
   while Fast /= null and then Fast.Next /= null loop
      Slow := Slow.Next;
      Fast := Fast.Next.Next;
      if Slow = Fast then
         raise Program_Error with "image frame list is cyclic";
      end if;
   end loop;
   while Current /= null loop
      if Current.Bytes = null or else Current.Length /= Current.Bytes'Length then
         raise Constraint_Error with "image frame length does not match data";
      end if;
      Register (Current.Bytes);
      if Count >= Positive'Last - 1 then
         raise Storage_Error with "image frame accounting overflow";
      end if;
      if Current.Number /= Count + 2 then
         raise Constraint_Error with "image frame numbers must be contiguous";
      end if;
      if Current.Length > Natural'Last - Bytes then
         raise Storage_Error with "image frame accounting overflow";
      end if;
      Count := Count + 1;
      Bytes := Bytes + Current.Length;
      Tail := Current;
      Current := Current.Next;
   end loop;
   Object.Frames := Head;
   Object.Frames_Tail := Tail;
   Object.Frame_Count := Positive (Count + 1);
   Object.Frame_Bytes := Bytes;
   begin
      Synchronize (Container, Object);
   exception
      when others =>
         Object.Frames := null;
         Object.Frames_Tail := null;
         Object.Frame_Count := 1;
         Object.Frame_Bytes := 0;
         raise;
   end;
   Head := null;
end Adopt_Frames;
