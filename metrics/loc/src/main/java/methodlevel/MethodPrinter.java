package methodlevel;

import japa.parser.JavaParser;
import japa.parser.ast.CompilationUnit;
import japa.parser.ast.body.MethodDeclaration;
import japa.parser.ast.visitor.VoidVisitorAdapter;

import java.io.File;
import java.io.FileInputStream;

public class MethodPrinter {

    public static void main(String[] args) throws Exception {
        // creates an input stream for the file to be parsed
    	String filename = new File(args[0]).getName();
        FileInputStream in = new FileInputStream(args[0]);
        

        CompilationUnit cu;
        try {
            // parse the file
            cu = JavaParser.parse(in);
        } finally {
            in.close();
        }

        // visit and print the methods names

        new MethodVisitor(filename).visit(cu, null);
    }

    /**
     * Simple visitor implementation for visiting MethodDeclaration nodes. 
     */
    private static class MethodVisitor extends VoidVisitorAdapter {
    	private String filename = "";
    	
    	public MethodVisitor(String filename) {
    		this.filename = filename;
    	}

        @Override
        public void visit(MethodDeclaration n, Object arg) {
            // here you can access the attributes of the method.
            // this method will be called for all methods in this 
            // CompilationUnit, including inner class methods
        	
        	int loc = 0;
        	if (n.getBody() != null)
        		loc = n.getBody().toString().split("\n").length;
        	System.out.println(this.filename + ":" + n.getName() + "()," + Integer.toString(loc));
        	
        	//System.out.println(n.getName());
            //System.out.println(n.getBody());
            //System.out.println("Lines of code: " + n.getBody().toString().split("\n").length);
        }
    }
}
