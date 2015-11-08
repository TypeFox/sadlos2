package com.ge.research.sadl.tests.model

import com.ge.research.sadl.jena.JenaBasedSadlModelProcessor
import com.ge.research.sadl.processing.ValidationAcceptor
import com.ge.research.sadl.sADL.SadlModel
import com.ge.research.sadl.tests.SADLInjectorProvider
import com.google.inject.Inject
import com.google.inject.Provider
import com.hp.hpl.jena.ontology.OntModel
import com.hp.hpl.jena.query.QueryExecutionFactory
import java.util.ArrayList
import java.util.List
import org.eclipse.xtext.junit4.InjectWith
import org.eclipse.xtext.junit4.XtextRunner
import org.eclipse.xtext.junit4.util.ParseHelper
import org.eclipse.xtext.junit4.validation.ValidationTestHelper
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.validation.Issue
import org.junit.Test
import org.junit.runner.RunWith

import static org.junit.Assert.*

@RunWith(XtextRunner)
@InjectWith(SADLInjectorProvider)
class SadlModelManagerProviderTest {
	
	@Inject ParseHelper<SadlModel> parser
	@Inject ValidationTestHelper validationTestHelper
	@Inject Provider<JenaBasedSadlModelProcessor> processorProvider
	
// TODO Is this the right place/method to check that errors are generated?	
	@Test def void invalidUriTestCase() {
		'''
			uri "my/uri" alias m1.
			Foo is a class.
		'''.assertInValidatesTo [ jenaModel, issues |
			// expectations go here
//			assertEquals("my/uri", modelManager.theJenaModel.getModelBaseURI())
			assertNotNull(jenaModel)
			assertEquals(1, issues.size())
			assertTrue(issues.toString(), issues.get(0).toString().contains("'my/uri' is not a valid URL"))
		]
	}
	
	@Test def void modelNameCase() {
		'''
			uri "http://sadl.org/model1" alias m1.
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			assertTrue(jenaModel.listOntologies().hasNext())
			assertTrue(jenaModel.listOntologies().next().URI.toString().equals("http://sadl.org/model1"))
		]
	}
	
	@Test def void mySimpleClassDeclarationCase() {
		'''
			uri "http://sadl.org/model1" alias m1.
			Foo is a class.
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var itr = jenaModel.listClasses().toIterable().iterator
			var found = false
			while (itr.hasNext()) {
				val nxt = itr.next;
				if (nxt.localName.equals("Foo")) {
					found = true;
				}
			}	
			assertTrue(found);
		]
	}
	
	@Test def void myClassWithPropertyDeclarationCase() {
		'''
			uri "http://sadl.org/model1" alias m1.
			Shape is a class described by area with values of type int.
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var prop = jenaModel.getOntProperty("http://sadl.org/model1#area")
			var itr = prop.listDomain().toIterable().iterator
			var found = false
			while (itr.hasNext()) {
				val nxt = itr.next;
				if (nxt.localName.equals("Shape")) {
					found = true;
				}
			}	
			if (!found) {
				jenaModel.write(System.out, "N3")
			}
			assertTrue(found);
			itr = prop.listRange().toIterable().iterator
			found = false;
			while (itr.hasNext()) {
				val nxt = itr.next;
				if (nxt.localName.equals("int")) {
					found = true;
				}
			}	
			if (!found) {
				jenaModel.write(System.out, "N3")
			}
		]
	}
	
	@Test def void mySubClassDeclarationCase() {
		'''
			uri "http://sadl.org/model1" alias m1.
			Food is a class.
			Pizza is a type of Food.
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var cls = jenaModel.getOntClass("http://sadl.org/model1#Pizza")
			var itr = cls.listSuperClasses(true).toIterable().iterator
			var found = false
			while (itr.hasNext()) {
				val nxt = itr.next;
				if (nxt.localName.equals("Food")) {
					found = true;
				}
			}
			if (!found) {
				jenaModel.write(System.out, "N3");
			}	
			assertTrue(found);
		]
	}
	
	@Test def void myUnionSuperClassClassDeclarationCase() {
		'''
			uri "http://sadl.org/model1" alias m1.
			Food is a class.
			Drink is a class.
			Refreshment is a type of {Food or Drink}.
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var itr = jenaModel.listClasses().toIterable().iterator
			var found = false
			while (itr.hasNext()) {
				val nxt = itr.next;
				if (nxt != null && nxt.isURIResource) {
					if (nxt.localName.equals("Refreshment")) {
						found = true;
						var sciter = nxt.listSuperClasses(true);
						while (sciter.hasNext()) {
							var sc = sciter.next();
							var uc = sc.asUnionClass();
							var operands = uc.listOperands();
							while (operands.hasNext) {
								var opcls = operands.next();
								assertTrue(opcls.localName.equals("Food") || opcls.localName.equals("Drink"));	
							}
						}
					}
				}
			}	
			if (!found) {
				jenaModel.write(System.out, "N3");
			}
			assertTrue(found);
		]
	}
	
	@Test def void myUnionSuperClassWithRestrictionClassDeclarationCase() {
		'''
			uri "http://sadl.org/model1" alias m1.
			Person is a class described by child with values of type Person.
			Parent is a type of {Person and (child has at least 1 value)}.
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var itr = jenaModel.listClasses().toIterable().iterator
			var found = false
			while (itr.hasNext()) {
				val nxt = itr.next;
				if (nxt != null && nxt.isURIResource) {
					if (nxt.localName.equals("Parent")) {
						found = true;
						var sciter = nxt.listSuperClasses(true);
						while (sciter.hasNext()) {
							var sc = sciter.next();
							var uc = sc.asIntersectionClass();
							var operands = uc.listOperands();
							var cnt = 0
							while (operands.hasNext) {
								var opcls = operands.next();
								assertTrue((opcls.URIResource && opcls.localName.equals("Person")) || opcls.isRestriction());
								cnt++	
							}
							assertTrue(cnt == 2)
						}
					}
				}
			}	
			if (!found) {
				jenaModel.write(System.out, "N3");
			}
			assertTrue(found);
		]
	}
	
	@Test def void myIntersectionSuperClassClassDeclarationCase() {
		'''
			uri "http://sadl.org/model1" alias m1.
			Liquid is a class.
			Consumable is a class.
			PotableLiquid is a type of {Liquid and Consumable}.
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var itr = jenaModel.listClasses().toIterable().iterator
			var found = false
			while (itr.hasNext()) {
				val nxt = itr.next;
				if (nxt != null && nxt.isURIResource) {
					if (nxt.localName.equals("PotableLiquid")) {
						found = true;
						var sciter = nxt.listSuperClasses(true);
						while (sciter.hasNext()) {
							var sc = sciter.next();
							var uc = sc.asIntersectionClass();
							var operands = uc.listOperands();
							while (operands.hasNext) {
								var opcls = operands.next();
								assertTrue(opcls.localName.equals("Liquid") || opcls.localName.equals("Consumable"));	
							}
						}
					}
				}
			}	
			if (!found) {
				jenaModel.write(System.out, "N3");
			}
			assertTrue(found);
		]
	}
	
	@Test def void mySimplePropertyDeclarationCase() {
		'''
			uri "http://sadl.org/model1" alias m1.
			prop is a property.
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var itr = jenaModel.listObjectProperties().toIterable().iterator
			var found = false
			while (itr.hasNext()) {
				val nxt = itr.next;
				if (nxt.localName.equals("prop")) {
					found = true;
				}
			}	
			assertTrue(found);
		]
	}
	
	@Test def void mySubPropertyDeclarationCase() {
		'''
			uri "http://sadl.org/model1" alias m1.
			prop1 is a property.
			prop2 is a type of prop1.
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var prop = jenaModel.getOntProperty("http://sadl.org/model1#prop2")
			var itr = prop.listSuperProperties(true).toIterable().iterator
			var found = false
			while (itr.hasNext()) {
				val nxt = itr.next;
				if (nxt.localName.equals("prop1")) {
					found = true;
				}
			}
			if (!found) {
				jenaModel.write(System.out, "N3")
			}	
			assertTrue(found);
		]
	}
	
	@Test def void myDisjointClassDeclarationCase1() {
		'''
			uri "http://sadl.org/model1" alias m1.
			Food is a class.
			Drink is a class.
			Poison is a class.
			Food and Drink and Poison are disjoint.
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var food = jenaModel.getOntClass("http://sadl.org/model1#Food")
			var drink = jenaModel.getOntClass("http://sadl.org/model1#Drink")
			var poison = jenaModel.getOntClass("http://sadl.org/model1#Poison")
			assertTrue("Food is disjoint from Drink", food.isDisjointWith(drink))
			assertTrue("Food is disjoint from Poison", food.isDisjointWith(poison))
			assertTrue("Drink is disjoint from Poison", drink.isDisjointWith(poison))
		]
	}
	
	@Test def void myDisjointClassDeclarationCase2() {
		'''
			uri "http://sadl.org/model1" alias m1.
			Food is a class.
			Drink is a class.
			Poison is a class.
			{Food, Drink, Poison} are disjoint.
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var food = jenaModel.getOntClass("http://sadl.org/model1#Food")
			var drink = jenaModel.getOntClass("http://sadl.org/model1#Drink")
			var poison = jenaModel.getOntClass("http://sadl.org/model1#Poison")
			assertTrue("Food is disjoint from Drink", food.isDisjointWith(drink))
			assertTrue("Food is disjoint from Poison", food.isDisjointWith(poison))
			assertTrue("Drink is disjoint from Poison", drink.isDisjointWith(poison))
		]
	}
	
	@Test def void mySameAsComplimentOfCase() {
		'''
			uri "http://sadl.org/model1" alias m1.
			Rich is a class.
			Poor is the same as not Rich.
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var rich = jenaModel.getOntClass("http://sadl.org/model1#Rich")
			var poor = jenaModel.getOntClass("http://sadl.org/model1#Poor")
			var itr = jenaModel.listStatements(rich, jenaModel.getOntProperty("http://www.w3.org/2002/07/owl#complimentOf"), poor)
			var found = false
			while (itr.hasNext) {
				var nxt = itr.next()
				System.out.println("Nxt: " + nxt.toString())
				found = true
			}
			if (!found) {
				jenaModel.write(System.out, "N3")				
			}
		]
	}
	
	@Test def void mySameAsCase1() {
		'''
			uri "http://sadl.org/model1" alias m1.
			Person is a class.
			Bill is a Person.
			William is a Person.
			Bill is the same as William.
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var bill = jenaModel.getIndividual("http://sadl.org/model1#Bill")
			var william = jenaModel.getIndividual("http://sadl.org/model1#William")
			var itr = jenaModel.listStatements(bill, jenaModel.getOntProperty("http://www.w3.org/2002/07/owl#sameAs"), william)
			var found = false
			while (itr.hasNext) {
				var nxt = itr.next()
				System.out.println("Nxt: " + nxt.toString())
				found = true
			}
			if (!found) {
				jenaModel.write(System.out, "N3")				
			}
			assertTrue(found)
		]
	}
	
	@Test def void myNotSameAsCase1() {
		'''
			uri "http://sadl.org/model1" alias m1.
			Person is a class.
			Bill is a Person.
			Hillary is a Person.
			Bill is not the same as Hillary.
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var itr = jenaModel.listAllDifferent()
			var error = false
			while (itr.hasNext) {
				var dfrm = itr.next()
				var itr2 = dfrm.listDistinctMembers()
				while (itr2.hasNext) {
					var nxt = itr2.next
					if (!nxt.toString().contains("Bill") && !nxt.toString().contains("Hillary")) {
						System.out.println("Nxt: " + nxt.toString())	
						error = true
						}
				}
			}
			if (!error) {
				jenaModel.write(System.out, "N3")				
			}
			assertFalse(error)
		]
	}
	
	@Test def void myNotSameAsCase2() {
		'''
			uri "http://sadl.org/model1" alias m1.
			Person is a class.
			Bill is a Person.
			Hillary is a Person.
			Chelsea is a Person.
			{Bill, Hillary, Chelsea} are not the same.
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var itr = jenaModel.listAllDifferent()
			var error = false
			while (itr.hasNext) {
				var dfrm = itr.next()
				var itr2 = dfrm.listDistinctMembers()
				while (itr2.hasNext) {
					var nxt = itr2.next
					if (!nxt.toString().contains("Bill") && !nxt.toString().contains("Hillary") && !nxt.toString().contains("Chelsea")) {
						System.out.println("Nxt: " + nxt.toString())	
						error = true
						}
				}
			}
			if (!error) {
				jenaModel.write(System.out, "N3")				
			}
			assertFalse(error)
		]
	}
	
	@Test def void myNecesaryAndSufficientCase1() {
		'''
		uri "http://sadl.org/TestSadlIde/AnonRestrictions" alias anonrest 
			version "$Revision: 1.3 $ Last modified on   $Date: 2015/06/30 21:27:33 $". 
		Artifact is a class.
		Person is a class described by owns with values of type Artifact.
		Manufacturer is a class.
		Apple is a Manufacturer.
		Dell is a Manufacturer.
		Computer is a type of Artifact described by manufacturer with values of type Manufacturer.
		Student is a type of Person.
		Professor is a class described by teaches with values of type Student.
		A Professor is an AppleProfessor only if teaches has at least one value of type
			{Student and (owns has at least one value of type {Computer and (manufacturer always has value Apple)})}.
		AppleLovingStudent is a type of Student, 
			described by owns with values of type {Computer and (manufacturer always has value Apple)}.
		A Computer is an AppleComputer only if manufacturer always has value Apple.		// necessary and sufficient conditions
		manufacturer of AppleComputer always has value Apple.							// hasValue restriction only		
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var error = true
			if (error) {
				jenaModel.write(System.out, "N3")				
			}
			assertFalse(!error)
		]
	}
	
	@Test def void myNecesaryAndSufficientCase2() {
		'''
		uri "http://sadl.org/TestSadlIde/AnonRestrictions" alias anonrest 
			version "$Revision: 1.3 $ Last modified on   $Date: 2015/06/30 21:27:33 $". 
		Person is a class described by owns with values of type Artifact.
		Artifact is a class.
		Manufacturer is a class.
		Apple is a Manufacturer.
		Dell is a Manufacturer.
		Computer is a type of Artifact described by manufacturer with values of type Manufacturer.
		Professor is a class described by teaches with values of type Student.
		Student is a type of Person.
		A Professor is an AppleProfessor only if teaches has at least one value of type
			{Student and (owns has at least one value of type {Computer and (manufacturer always has value Apple)})}.
		AppleLovingStudent is a type of Student, 
			described by owns with values of type {Computer and (manufacturer always has value Apple)}.
		A Computer is an AppleComputer only if manufacturer always has value Apple.		// necessary and sufficient conditions
		manufacturer of AppleComputer always has value Apple.							// hasValue restriction only		
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var q1 = "prefix owl: <http://www.w3.org/2002/07/owl#> " +
				"prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> " +
				"prefix ar: <http://sadl.org/TestSadlIde/AnonRestrictions#> " +
				"select distinct ?p ?v where {?r rdf:type owl:Restriction . ?r owl:onProperty ?p . ?r owl:hasValue ?v}"
    		assertTrue(queryResultContains(jenaModel, q1, "http://sadl.org/TestSadlIde/AnonRestrictions#manufacturer http://sadl.org/TestSadlIde/AnonRestrictions#Apple"))
			var q2 = "prefix owl: <http://www.w3.org/2002/07/owl#> " +
				"prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> " +
				"prefix ar: <http://sadl.org/TestSadlIde/AnonRestrictions#> " +
				"select distinct ?p where {?r rdf:type owl:Restriction . ?r owl:onProperty ?p . ?r owl:someValuesFrom ?v}"
    		assertTrue(queryResultContains(jenaModel, q2, "http://sadl.org/TestSadlIde/AnonRestrictions#teaches"))
    		assertTrue(queryResultContains(jenaModel, q2, "http://sadl.org/TestSadlIde/AnonRestrictions#owns"))
			var q3 = "prefix owl: <http://www.w3.org/2002/07/owl#> " +
				"prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> " +
				"prefix ar: <http://sadl.org/TestSadlIde/AnonRestrictions#> " +
				"select distinct ?p ?v where {?r rdf:type owl:Restriction . ?r owl:onProperty ?p . ?r owl:allValuesFrom ?v}"
    		assertFalse(queryResultContains(jenaModel, q3, "http://sadl.org/TestSadlIde/AnonRestrictions#manufacturer http://sadl.org/TestSadlIde/AnonRestrictions#Apple"))

			var showModel = true
			if (showModel) {
				jenaModel.write(System.out, "N3")				
			}
		]
	}
		
	@Test def void myNecesaryAndSufficientCase3() {
		'''
		uri "http://sadl.org/TestSadlIde/AnonRestrictions" alias anonrest 
			version "$Revision: 1.3 $ Last modified on   $Date: 2015/06/30 21:27:33 $". 
		Person is a class described by owns with values of type Artifact.
		Artifact is a class.
		Manufacturer is a class.
		Apple is a Manufacturer.
		Dell is a Manufacturer.
		Computer is a type of Artifact described by manufacturer with values of type Manufacturer.
		Professor is a class described by teaches with values of type Student.
		Student is a type of Person.
		A Professor is an AppleProfessor only if teaches has at least one value of type
			{Student and (owns has at least one value of type {Computer and (manufacturer always has value Apple)})}.
		AppleLovingStudent is a type of Student, 
			described by owns only has values of type {Computer and (manufacturer always has value Apple)}.
		A Computer is an AppleComputer only if manufacturer always has value Apple.		// necessary and sufficient conditions
		manufacturer of AppleComputer always has value Apple.							// hasValue restriction only		
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var q1 = "prefix owl: <http://www.w3.org/2002/07/owl#> " +
				"prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> " +
				"prefix ar: <http://sadl.org/TestSadlIde/AnonRestrictions#> " +
				"select distinct ?p ?v where {?r rdf:type owl:Restriction . ?r owl:onProperty ?p . ?r owl:hasValue ?v}"
    		assertTrue(queryResultContains(jenaModel, q1, "http://sadl.org/TestSadlIde/AnonRestrictions#manufacturer http://sadl.org/TestSadlIde/AnonRestrictions#Apple"))
			var q2 = "prefix owl: <http://www.w3.org/2002/07/owl#> " +
				"prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> " +
				"prefix ar: <http://sadl.org/TestSadlIde/AnonRestrictions#> " +
				"select distinct ?p where {?r rdf:type owl:Restriction . ?r owl:onProperty ?p . ?r owl:someValuesFrom ?v}"
    		assertTrue(queryResultContains(jenaModel, q2, "http://sadl.org/TestSadlIde/AnonRestrictions#teaches"))
    		assertTrue(queryResultContains(jenaModel, q2, "http://sadl.org/TestSadlIde/AnonRestrictions#owns"))
			var q3 = "prefix owl: <http://www.w3.org/2002/07/owl#> " +
				"prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> " +
				"prefix ar: <http://sadl.org/TestSadlIde/AnonRestrictions#> " +
				"select distinct ?p ?v where {?r rdf:type owl:Restriction . ?r owl:onProperty ?p . ?r owl:allValuesFrom ?v}"
    		assertFalse(queryResultContains(jenaModel, q3, "http://sadl.org/TestSadlIde/AnonRestrictions#manufacturer http://sadl.org/TestSadlIde/AnonRestrictions#Apple"))

			var showModel = true
			if (showModel) {
				jenaModel.write(System.out, "N3")				
			}
		]
	}
	
		@Test def void myNecesaryAndSufficientCase4() {
		'''
		uri "http://sadl.org/TestSadlIde/AnonRestrictions" alias anonrest 
			version "$Revision: 1.3 $ Last modified on   $Date: 2015/06/30 21:27:33 $". 
		Artifact is a class.
		Manufacturer is a class.
		Apple is a Manufacturer.
		Computer is a type of Artifact described by manufacturer with values of type Manufacturer.
		AppleComputer is a type of Computer.
		manufacturer of AppleComputer always has value Apple.							// hasValue restriction only		
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var q1 = "prefix owl: <http://www.w3.org/2002/07/owl#> " +
				"prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> " +
				"prefix ar: <http://sadl.org/TestSadlIde/AnonRestrictions#> " +
				"select distinct ?p ?v where {?r rdf:type owl:Restriction . ?r owl:onProperty ?p . ?r owl:hasValue ?v}"
    		assertTrue(queryResultContains(jenaModel, q1, "http://sadl.org/TestSadlIde/AnonRestrictions#manufacturer http://sadl.org/TestSadlIde/AnonRestrictions#Apple"))
			var q2 = "prefix owl: <http://www.w3.org/2002/07/owl#> " +
				"prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> " +
				"prefix ar: <http://sadl.org/TestSadlIde/AnonRestrictions#> " +
				"select distinct ?p where {?r rdf:type owl:Restriction . ?r owl:onProperty ?p . ?r owl:someValuesFrom ?v}"
    		assertFalse(queryResultContains(jenaModel, q2, "http://sadl.org/TestSadlIde/AnonRestrictions#teaches"))
    		assertFalse(queryResultContains(jenaModel, q2, "http://sadl.org/TestSadlIde/AnonRestrictions#owns"))
			var q3 = "prefix owl: <http://www.w3.org/2002/07/owl#> " +
				"prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> " +
				"prefix ar: <http://sadl.org/TestSadlIde/AnonRestrictions#> " +
				"select distinct ?p ?v where {?r rdf:type owl:Restriction . ?r owl:onProperty ?p . ?r owl:allValuesFrom ?v}"
    		assertFalse(queryResultContains(jenaModel, q3, "http://sadl.org/TestSadlIde/AnonRestrictions#manufacturer http://sadl.org/TestSadlIde/AnonRestrictions#Apple"))

			var showModel = true
			if (showModel) {
				jenaModel.write(System.out, "N3")				
			}
		]
	}
	
	@Test def void mySimpleInstanceDeclarationCase() {
		'''
			uri "http://sadl.org/model1" alias m1.
			Foo is a class.
			MyFoo is a Foo.
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var itr = jenaModel.listIndividuals().toIterable().iterator
			var found = false
			while (itr.hasNext()) {
				val nxt = itr.next;
				if (nxt.localName.equals("MyFoo")) {
					found = true;
				}
			}	
			assertTrue(found);
		]
	}
	
	@Test def void myAnnotationPropertyDeclarationCase() {
		'''
			uri "http://sadl.org/model1" alias m1.
			annprop is a type of annotation.
		'''.assertValidatesTo [ jenaModel, issues |
			// expectations go here
			assertNotNull(jenaModel)
			assertTrue(issues.size == 0)
			var itr = jenaModel.listAnnotationProperties().toIterable().iterator
			var found = false
			while (itr.hasNext()) {
				val nxt = itr.next;
				if (nxt.localName.equals("annprop")) {
					found = true;
				}
			}	
			if (!found) {
				jenaModel.write(System.out, "N3")				
			}
			assertTrue(found);
		]
	}
	
	protected def boolean queryResultContains(OntModel m, String q, String r) {
		var qe = QueryExecutionFactory.create(q, m)
		var results =  qe.execSelect()
		var vars = results.resultVars
    	var resultsList = new ArrayList<String>()
    	while (results.hasNext()) {
    		var result = results.next()
    		var sb = new StringBuffer();
    		var cntr = 0
    		for (var c = 0; c < vars.size(); c++) {
    			if (cntr++ > 0) {
    				sb.append(" ")
    			}
    			sb.append(result.get(vars.get(c)))
    		}
    		resultsList.add(sb.toString())
    	}
    	if (resultsList.contains(r)) {
    		return true
    	}
    	System.out.println("Query result does not contain '" + r + "':")
    	var itr = resultsList.iterator()
    	if (itr.hasNext()) {
    		while (itr.hasNext()) {
    			System.out.println("   " + itr.next().toString())
    		}
    	}
    	else {
    		System.out.println("    Query returned no results");
    	}
    	return false
	}
	
	protected def void assertValidatesTo(CharSequence code, (OntModel, List<Issue>)=>void assertions) {
		val model = parser.parse(code)
		validationTestHelper.assertNoErrors(model)
		val processor = processorProvider.get
		val List<Issue> issues= newArrayList
		processor.onValidate(model.eResource, new ValidationAcceptor([issues += it]), CancelIndicator.NullImpl)
		assertions.apply(processor.theJenaModel, issues)
	}

	protected def void assertInValidatesTo(CharSequence code, (OntModel, List<Issue>)=>void assertions) {
		val model = parser.parse(code);
		val xtextIssues = validationTestHelper.validate(model);
		val processor = processorProvider.get
		val List<Issue> issues= new ArrayList(xtextIssues);
		processor.onValidate(model.eResource, new ValidationAcceptor([issues += it]), CancelIndicator.NullImpl)
		assertions.apply(processor.theJenaModel, issues)
	}
}