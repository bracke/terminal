package body Terminal.App.Vulkan_Creation_Plan is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;

   function Build_Queue_Plan
     (Graphics_Family : Natural;
      Present_Family  : Natural) return Queue_Plan
   is
      Split : constant Boolean := Graphics_Family /= Present_Family;
   begin
      return
        (Graphics_Family              =>
           Interfaces.Unsigned_32 (Graphics_Family),
         Present_Family               =>
           Interfaces.Unsigned_32 (Present_Family),
         Device_Queue_Info_Count      => (if Split then 2 else 1),
         Swapchain_Queue_Family_Count => (if Split then 2 else 0),
         Concurrent_Sharing           => Split);
   end Build_Queue_Plan;

   function Extent_Is_Valid
     (Width, Height     : Interfaces.Unsigned_32;
      Maximum_Dimension : Positive) return Boolean
   is
      Limit : constant Interfaces.Unsigned_64 :=
        Interfaces.Unsigned_64
          (Natural'Min (Natural'Last, Maximum_Dimension));
   begin
      return Width > 0
        and then Height > 0
        and then Interfaces.Unsigned_64 (Width) <= Limit
        and then Interfaces.Unsigned_64 (Height) <= Limit;
   end Extent_Is_Valid;
end Terminal.App.Vulkan_Creation_Plan;
