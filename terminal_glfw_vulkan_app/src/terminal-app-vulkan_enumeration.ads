with Interfaces;
with System;
with Vk;

generic
   type Element_Type is private;
   type Element_Array is array (Positive range <>) of Element_Type;
   type Element_Array_Access is access Element_Array;
   with function Query
     (Count : not null access Interfaces.Unsigned_32;
      Data  : System.Address) return Vk.Result_T;
package Terminal.App.Vulkan_Enumeration is
   type Fetch_Status is
     (Fetch_Ready,
      Fetch_Empty,
      Fetch_Query_Failed,
      Fetch_Count_Too_Large,
      Fetch_Retry_Exhausted);

   procedure Fetch
     (Retry_Limit   : Positive;
      Maximum_Items : Positive;
      Items         : out Element_Array_Access;
      Count         : out Natural;
      Status        : out Fetch_Status);
end Terminal.App.Vulkan_Enumeration;
