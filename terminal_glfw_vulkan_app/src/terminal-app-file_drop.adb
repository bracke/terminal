with Interfaces.C.Strings;

package body Terminal.App.File_Drop is
   package CStr renames Interfaces.C.Strings;
   use type CStr.chars_ptr;
   use type System.Address;

   type Path_Callback is access procedure (Path : CStr.chars_ptr)
     with Convention => C;
   procedure Install
     (Window : System.Address;
      Callback : Path_Callback)
     with Import, Convention => C, External_Name => "bracke_file_drop_install";
   procedure Uninstall (Window : System.Address)
     with Import, Convention => C, External_Name => "bracke_file_drop_uninstall";

   type Path_Array is array (Positive range 1 .. Max_Pending_Paths) of Path_Value;
   protected Queue is
      procedure Push (Value : String);
      procedure Pop (Value : out Path_Value; Available : out Boolean);
      function Overflows return Natural;
   private
      Items : Path_Array;
      Head : Positive range 1 .. Max_Pending_Paths := 1;
      Tail : Positive range 1 .. Max_Pending_Paths := 1;
      Count : Natural range 0 .. Max_Pending_Paths := 0;
      Dropped : Natural := 0;
   end Queue;

   protected body Queue is
      procedure Push (Value : String) is
         Length : constant Natural := Natural'Min (Value'Length, Max_Path_Length);
      begin
         if Count = Max_Pending_Paths then
            Dropped := Dropped + 1;
            return;
         end if;
         Items (Tail) := (others => <>);
         Items (Tail).Length := Length;
         if Length > 0 then
            Items (Tail).Data (1 .. Length) :=
              Value (Value'First .. Value'First + Length - 1);
         end if;
         Tail := (if Tail = Max_Pending_Paths then 1 else Tail + 1);
         Count := Count + 1;
      end Push;

      procedure Pop (Value : out Path_Value; Available : out Boolean) is
      begin
         Available := Count > 0;
         if not Available then
            Value := (others => <>);
            return;
         end if;
         Value := Items (Head);
         Items (Head) := (others => <>);
         Head := (if Head = Max_Pending_Paths then 1 else Head + 1);
         Count := Count - 1;
      end Pop;

      function Overflows return Natural is (Dropped);
   end Queue;

   procedure On_Path (Path : CStr.chars_ptr) with Convention => C;
   procedure On_Path (Path : CStr.chars_ptr) is
   begin
      if Path /= CStr.Null_Ptr then
         Enqueue (CStr.Value (Path));
      end if;
   exception
      when others => null;
   end On_Path;

   function Text (Value : Path_Value) return String is
     (if Value.Length = 0 then "" else Value.Data (1 .. Value.Length));

   procedure Initialize
     (Window : System.Address;
      Status : out Install_Status) is
   begin
      if Window = System.Null_Address then
         Status := Invalid_Window;
      else
         Install (Window, On_Path'Access);
         Status := Installed;
      end if;
   end Initialize;

   procedure Finalize (Window : System.Address) is
   begin
      if Window /= System.Null_Address then Uninstall (Window); end if;
   end Finalize;

   procedure Poll (Value : out Path_Value; Available : out Boolean) is
   begin
      Queue.Pop (Value, Available);
   end Poll;

   procedure Enqueue (Path : String) is
   begin
      Queue.Push (Path);
   end Enqueue;

   function Overflow_Count return Natural is (Queue.Overflows);
end Terminal.App.File_Drop;
