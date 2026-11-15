with Ada.Unchecked_Deallocation;

package body Terminal.App.Vulkan_Enumeration is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Vk.Result_T;

   procedure Free is new Ada.Unchecked_Deallocation
     (Element_Array, Element_Array_Access);

   function Fits_Natural (Value : Interfaces.Unsigned_32) return Boolean is
     (Interfaces.Unsigned_64 (Value) <=
        Interfaces.Unsigned_64 (Natural'Last));

   procedure Fetch
     (Retry_Limit   : Positive;
      Maximum_Items : Positive;
      Items         : out Element_Array_Access;
      Count         : out Natural;
      Status        : out Fetch_Status)
   is
      Reported : aliased Interfaces.Unsigned_32 := 0;
      Result   : Vk.Result_T;
      Capacity : Natural;
   begin
      Items := null;
      Count := 0;
      Status := Fetch_Query_Failed;

      for Attempt in 1 .. Retry_Limit loop
         Reported := 0;
         Result := Query (Reported'Access, System.Null_Address);
         if Result /= Vk.SUCCESS then
            Status := Fetch_Query_Failed;
            return;
         elsif Reported = 0 then
            Status := Fetch_Empty;
            return;
         elsif not Fits_Natural (Reported)
           or else Interfaces.Unsigned_64 (Reported) >
             Interfaces.Unsigned_64 (Maximum_Items)
         then
            Status := Fetch_Count_Too_Large;
            return;
         end if;

         Capacity := Natural (Reported);
         Items := new Element_Array (1 .. Capacity);
         Result := Query (Reported'Access, Items.all'Address);
         if Result = Vk.INCOMPLETE then
            Free (Items);
         elsif Result /= Vk.SUCCESS then
            Free (Items);
            Status := Fetch_Query_Failed;
            return;
         elsif Reported = 0 then
            Free (Items);
            Status := Fetch_Empty;
            return;
         elsif not Fits_Natural (Reported)
           or else Interfaces.Unsigned_64 (Reported) >
             Interfaces.Unsigned_64 (Maximum_Items)
           or else Natural (Reported) > Capacity
         then
            Free (Items);
            Status := Fetch_Count_Too_Large;
            return;
         else
            Count := Natural (Reported);
            Status := Fetch_Ready;
            return;
         end if;
      end loop;

      Status := Fetch_Retry_Exhausted;
   exception
      when Storage_Error =>
         Free (Items);
         Count := 0;
         Status := Fetch_Query_Failed;
      when others =>
         Free (Items);
         Count := 0;
         raise;
   end Fetch;
end Terminal.App.Vulkan_Enumeration;
