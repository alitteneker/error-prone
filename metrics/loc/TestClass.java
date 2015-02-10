package methodlevel;

public class TestClass {
	public int a(int x, int y) {
		int c = x;
		c += y;
		c *= x;
		return c;
	}
	
	public float b(int x, int y) {
		float c = 1.0f;
		c += Math.sin(y);
		return c;
	}
}
