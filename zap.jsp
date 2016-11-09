<%@ taglib prefix="cs" uri="futuretense_cs/ftcs1_0.tld"%><%@ taglib
	prefix="asset" uri="futuretense_cs/asset.tld"%><%@ taglib
	prefix="assetset" uri="futuretense_cs/assetset.tld"%><%@ taglib
	prefix="commercecontext" uri="futuretense_cs/commercecontext.tld"%><%@ taglib
	prefix="ics" uri="futuretense_cs/ics.tld"%><%@ taglib
	prefix="listobject" uri="futuretense_cs/listobject.tld"%><%@ taglib
	prefix="render" uri="futuretense_cs/render.tld"%><%@ taglib
	prefix="searchstate" uri="futuretense_cs/searchstate.tld"%><%@ taglib
	prefix="siteplan" uri="futuretense_cs/siteplan.tld"%><%@ page
	import="COM.FutureTense.Interfaces.*,
                   COM.FutureTense.Util.ftMessage,
                   com.fatwire.assetapi.data.*,
                   com.fatwire.assetapi.query.*,
                   com.fatwire.assetapi.*,
                   COM.FutureTense.Util.ftErrors,
                   com.fatwire.system.*,
                   java.util.*,
                   com.openmarket.xcelerate.asset.*,
                   com.fatwire.assetapi.def.*,
                   java.io.*,
                   com.fatwire.assetapi.common.*,
                   com.fatwire.services.*,
                   com.fatwire.services.beans.entity.*"%><cs:ftcs>

<%!





%>
	<%!public List<String> dumpAssetAsList(String relationshipType, String relationshipName, String parent, ICS ics, int depth, List<AssetId> memory, AssetId assetidentifier, String destinationId) {
		
		AssetDataManager mgr = (AssetDataManager) SessionFactory.getSession().getManager(AssetDataManager.class.getName());
		
		String ASSETSEP = " ##### Level ";
		List<String> r = new ArrayList<String>();

		ics.LogMsg("trying to dump " + assetidentifier + ", depth=" + depth);
		if (memory.contains(assetidentifier)) {
			ics.LogMsg("already visited " + assetidentifier);
			return r;
		}

		if (depth > 50) {
			ics.LogMsg("depth limit reached");
			return r;
		}

		memory.add(assetidentifier);

		try {

			Iterable<AssetData> assets = mgr.read(Collections.singletonList(assetidentifier));
			// TODO can i get rid of this stupid loop, there should only be one asset
			int numassets = 0;
			for (AssetData asset : assets) {

				r.add(ASSETSEP + depth);
				r.add(relationshipType);
				r.add(relationshipName);
				r.add(parent);
				if (numassets > 1) {
					ics.LogMsg("weirdly there seem to be " + numassets + " assets of " + asset.toString());
				}
				String assetType = assetidentifier.getType();
				String assetId = Long.toString(assetidentifier.getId());

				
				String lastPubDate = "unknown";
				if (!destinationId.isEmpty()) {
				try {
					ServicesManager sm = (ServicesManager) SessionFactory.getSession().getManager(ServicesManager.class.getName());
					ApprovalService as = sm.getApprovalService();
					lastPubDate = as.getLastPublishDate(Long.parseLong(destinationId), assetidentifier).toString();
				} catch (Exception e) {
					System.out.println(e.toString());
				}
				r.add("last published: " + lastPubDate);
				} else {
					r.add("last published: not checked");
				}
				
				
				String[] attrnames = {"name", "description", "Webreference", "category", "updateddate", "template", "status", "subtype", "Publist", "Dimension"};
				List<String> attrnamesList = Arrays.asList(attrnames);
				Map<String,String> attrmap = new HashMap<String,String>();
				for (String attrname : attrnamesList) {
					String attrvalue = "NULL";
					if (asset.getAttributeData(attrname) != null && asset.getAttributeData(attrname).getData() != null) {
						attrvalue = asset.getAttributeData(attrname).getData().toString();
					}
					attrmap.put(attrname, attrvalue);
				}
				
				String assetDefinitionName = asset.getAssetTypeDef().getName();
				String assetDefinitionDescription = asset.getAssetTypeDef().getDescription();
				String assetDefinitionSubtype = asset.getAssetTypeDef().getSubtype();
				String assetDefinitionPlural = asset.getAssetTypeDef().getPlural();

				// build our discovered data for this bit
				r.add(assetType);
				r.add(assetId);
				r.add(attrmap.get("name"));
				r.add(attrmap.get("description"));
				if (assetType.compareTo("Page") == 0) {
					//r.add(attrmap.get("Webreference")); // TODO get a WebReferenceImpl
				}
				r.add(attrmap.get("Webreference")); // TODO get a WebReferenceImpl
				r.add(attrmap.get("category"));
				r.add(attrmap.get("updateddate"));
				r.add(attrmap.get("template"));
				r.add(attrmap.get("status"));
				r.add(attrmap.get("subtype"));
				//r.add(attrmap.get("Publist"));
				r.add(attrmap.get("Dimension"));
				r.add(assetDefinitionName);
				r.add(assetDefinitionDescription);
				r.add(assetDefinitionSubtype);
				r.add(assetDefinitionPlural);

				// identify the attributes of type asset
				for (AttributeData attr : asset.getAttributeData()) {
					String attributeName = attr.getAttributeName();
					String attributeType = attr.getType().toString();
					String attributeDefinitionName = attr.getAttributeDef().getName();
					String attributeDefinitionDescription = attr.getAttributeDef().getDescription();

					//ics.LogMsg("found attribute " + attributeName + " of type " + attributeType);

					// descend into attributes of type asset, except for some we disregard
					String[] attrsToDisregard = {"flextemplateid", "SPTParent", "renderid", "flexgrouptemplateid"};
					List<String> attrsToDisregardList = Arrays.asList(attrsToDisregard);
					
					if ((attributeType.compareTo("asset") == 0) && (!attrsToDisregardList.contains(attributeName))) {
						// build our discovered data for this bit
						// may be multiple values (assets) in this attribute
						List<AssetId> attributesOfTypeAsset = (List<AssetId>) attr.getDataAsList();
						for (AssetId attributeOfTypeAsset : attributesOfTypeAsset) {
							// now we need to dive into this attribute of type asset
							r.addAll(dumpAssetAsList("attribute of type asset", attributeName, assetidentifier.toString(), ics, depth + 1, memory, attributeOfTypeAsset, destinationId));
						}
					}
				}
				// done iterating over the attributes of type asset

				List<AssetAssociationDef> assetPossibleAssociations = asset.getAssetTypeDef().getAssociations();
				// get named associations
				for (AssetAssociationDef aad : assetPossibleAssociations) {
					String assocname = aad.getName();
					List<AssetId> assocassets = asset.getAssociatedAssets(assocname);
					for (AssetId assocasset : assocassets) {
						//ics.LogMsg("found named association " + assocname + " to " + assocasset);
						r.addAll(dumpAssetAsList("named association", assocname, assetidentifier.toString(), ics, depth + 1, memory, assocasset, destinationId));
					}
				}
				// get unnamed associations
				List<AssetId> assocassets = asset.getAssociatedAssets(AssetAssociationDef.UnnamedAssociationName);
				for (AssetId assocasset : assocassets) {
					//ics.LogMsg("found unnamed association to " + assocasset);
					r.addAll(dumpAssetAsList("unnamed association", "", assetidentifier.toString(), ics, depth + 1, memory, assocasset, destinationId));
				}
			}
			// should have only been one asset in that loop, but lets check
			numassets++;
		} catch (AssetAccessException e) {
			StringWriter sw = new StringWriter();
			PrintWriter pw = new PrintWriter(sw);
			e.printStackTrace(pw);
			String exceptionStr = sw.toString();

			ics.LogMsg("hairy exception " + exceptionStr);
			r.add(exceptionStr);
		}
		return r;
	}%>





<%! public String wrapInTd(List<String> input) {
	String r = "";
	for (String inp : input) {
		r+= "<td>" + inp + "</td>";
	}
	return r;
}
%>

	<h1>Zap</h1>







	<%
			String assettype = "";
			String assetid = "";
			String query = "";
			int limit = 10;
			String pagename = "";
			String destinationId = "";
			String submit = "";

			if (ics.GetVar("assettype") != null)
				assettype = ics.GetVar("assettype");
			if (ics.GetVar("assetid") != null)
				assetid = ics.GetVar("assetid");
			if (ics.GetVar("query") != null)
				query = ics.GetVar("query");
			if (ics.GetVar("limit") != null)
				limit = Integer.parseInt(ics.GetVar("limit"));
			if (ics.GetVar("destinationId") != null)
				destinationId = ics.GetVar("destinationId");
			if (ics.GetVar("pagename") != null)
				pagename = ics.GetVar("pagename");
			if (ics.GetVar("submit") != null)
				submit = ics.GetVar("submit");
			
			
			try {
				ServicesManager sm = (ServicesManager) SessionFactory.getSession().getManager(ServicesManager.class.getName());
				ApprovalService as = sm.getApprovalService();
				
				List<DestinationBean> destinations = as.getDestinations(1322052581735L);
				out.println("Destinations:<table border=\"2\">");
				for (DestinationBean dest : destinations) {
					out.println("<tr><td>" + dest.getName() + "</td><td>" + dest.getId() + "</td><td>" + dest.getType()
							 + "</td></tr>");
				}
				out.println("</table><p/>");
			} catch (Exception e) {
				System.out.println(e.toString());
			}
			
			out.println("<form>");
			out.println("<input type='hidden' name='pagename' value='" + pagename + "'/>");
			out.println("Provide an assettype & assetid:<br />");
			out.println("assettype <input type='text' name='assettype' value='" + assettype + "'/>");
			out.println("assetid <input type='text' name='assetid' value='" + assetid + "'/><p/>");
			out.println("or a sql query that returns two columns, assetid and assettype, and limit on max number of assets:<br/>");
			out.println("sql query <textarea name='query' rows='5' cols='80'>" + query + "</textarea><br/>");
			out.println("limit <input type='text' name='limit' value='" + limit + "'><p/>");
		
			out.println("for which destination <input type='text' name='destinationId' value='" + destinationId + "'/><p/>");
			out.println("<input name='submit' type='submit' />");
			out.println("</form><p/>");

			if (!submit.isEmpty()) {
				out.println("assettype = " + assettype + "<br/>");
				out.println("assetid = " + assetid + "<br/>");
				out.println("query = " + query + "<br/>");

				List<AssetId> todoAssets = new ArrayList<AssetId>();

				if ((!assettype.isEmpty()) && (Long.parseLong(assetid) != 0)) {
					AssetId specificStartAsset = new AssetIdImpl(assettype, Long.parseLong(assetid));
					todoAssets.add(specificStartAsset);
				}

				if (!query.isEmpty()) {
					StringBuffer sb = new StringBuffer();
					IList queryResults = ics.SQL("SystemInfo", query, "querylist", limit, true, sb);
					for (int i = 1; i <= queryResults.numRows(); i++) {
						queryResults.moveTo(i);
						String queryAssetType = queryResults.getValue("assettype");
						long queryAssetid = Long.parseLong(queryResults.getValue("assetid"));
						AssetId queryAsset = new AssetIdImpl(queryAssetType, queryAssetid);
						todoAssets.add(queryAsset);
					}
				}

				// if nothing provided, default to a specific asset
				if (todoAssets.isEmpty()) {
					AssetId defaultStartAsset = new AssetIdImpl("Page", 1327351719456L);
					//AssetId defaultStartAsset = new AssetIdImpl("AVIArticle", 1463176425160L);
					todoAssets.add(defaultStartAsset);
				}

				int i = 1;
				out.println("processing " + todoAssets.size() + " assets<br/>");

				out.println("<table border=\"2\">");
				// dump assets on the todo list
				for (AssetId asset : todoAssets) {

					List<String> rx = new ArrayList<String>();

					// memory of visited assets;
					List<AssetId> memory = new ArrayList<AssetId>();
					ics.LogMsg("outer loop dumping " + i + " of " + todoAssets.size() + ", " + asset);
					i++;
					rx.addAll(dumpAssetAsList("", "", "", ics, 0, memory, asset, destinationId));

					
					
					/*
					out.println("<tr>");
					for (String field : rx) {
						out.println("<td>" + field + "</td>");
					}
					out.println("</tr>");
					*/
					
					// flat html table output

					int numColsPerAsset = 20;
					// how many assets are on this list
					int numAssets = rx.size() / numColsPerAsset;
					// get the pagecols
					List<String> pagecols = rx.subList(0, numColsPerAsset);
					
					if (numAssets == 1) {
						out.println("<tr>" + wrapInTd(pagecols) + "</tr>");
					} else {
						for (int n=1; n < numAssets; n++) {
							List<String> childcols = rx.subList(n*numColsPerAsset, (n*numColsPerAsset) + numColsPerAsset);
							out.println("<tr>" + wrapInTd(pagecols) + wrapInTd(childcols) + "</tr>");
						}
					}
				}
				out.println("</table>");
			}
	%>

</cs:ftcs>
