// NEGATIVE CONTROL - deliberately broken source, used only to prove that
// tools\compile-check.ps1 actually reports errors and a non-zero exit code.
namespace GiantVillagersNegativeControl
{
    public class Broken
    {
        public void X()
        {
            NotARealType y = null;
            System.Console.WriteLine(y);
        }
    }
}
